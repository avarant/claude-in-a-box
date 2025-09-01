#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== EC2 Instance Setup Script ===${NC}"
echo ""

# Prompt for user inputs
read -p "Enter instance name: " INSTANCE_NAME
read -p "Enter AWS region (default: us-west-2): " AWS_REGION
AWS_REGION=${AWS_REGION:-us-west-2}
read -p "Enter EC2 instance type (default: t3.medium): " INSTANCE_TYPE
INSTANCE_TYPE=${INSTANCE_TYPE:-t3.medium}

echo ""
echo -e "${YELLOW}Configuration:${NC}"
echo "  Instance Name: $INSTANCE_NAME"
echo "  AWS Region: $AWS_REGION"
echo "  Instance Type: $INSTANCE_TYPE"
echo ""
read -p "Proceed with this configuration? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 1
fi

# Generate unique identifiers
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
KEY_NAME="${INSTANCE_NAME}-key-${TIMESTAMP}"
KEY_PATH="./${KEY_NAME}.pem"
SG_NAME="${INSTANCE_NAME}-sg-${TIMESTAMP}"

echo ""
echo -e "${GREEN}Step 1: Generating SSH Key Pair${NC}"
# Generate SSH key pair locally
ssh-keygen -t rsa -b 4096 -f "${KEY_PATH}" -N "" -C "${INSTANCE_NAME}-access-key" >/dev/null 2>&1
chmod 600 "${KEY_PATH}"
echo "Local SSH key generated: ${KEY_PATH}"

# Import key to AWS
echo "Importing SSH key to AWS..."
aws ec2 import-key-pair \
    --key-name "${KEY_NAME}" \
    --public-key-material fileb://"${KEY_PATH}.pub" \
    --region "${AWS_REGION}" >/dev/null
echo "SSH key imported to AWS: ${KEY_NAME}"

echo ""
echo -e "${GREEN}Step 2: Fetching Cloudflare IP Ranges${NC}"
# Fetch Cloudflare IP ranges
CF_IPV4=$(curl -s https://www.cloudflare.com/ips-v4)
CF_IPV6=$(curl -s https://www.cloudflare.com/ips-v6)
echo "Cloudflare IP ranges fetched successfully"

echo ""
echo -e "${GREEN}Step 3: Creating Security Group${NC}"
# Create security group
VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=is-default,Values=true" \
    --query "Vpcs[0].VpcId" \
    --output text \
    --region "${AWS_REGION}")

SG_ID=$(aws ec2 create-security-group \
    --group-name "${SG_NAME}" \
    --description "Security group for ${INSTANCE_NAME} - SSH public, HTTP/HTTPS Cloudflare only" \
    --vpc-id "${VPC_ID}" \
    --region "${AWS_REGION}" \
    --output text \
    --query 'GroupId')

echo "Security group created: ${SG_ID}"

# Add SSH rule (port 22 open to public)
echo "Adding SSH access rule (0.0.0.0/0)..."
aws ec2 authorize-security-group-ingress \
    --group-id "${SG_ID}" \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    --region "${AWS_REGION}" >/dev/null

# Add HTTP/HTTPS rules for Cloudflare IPs
echo "Adding HTTP/HTTPS rules for Cloudflare IPs..."

# Add rules for each Cloudflare IPv4 range
for ip in $CF_IPV4; do
    # HTTP (port 80)
    aws ec2 authorize-security-group-ingress \
        --group-id "${SG_ID}" \
        --protocol tcp \
        --port 80 \
        --cidr "${ip}" \
        --region "${AWS_REGION}" >/dev/null 2>&1 || true
    
    # HTTPS (port 443)
    aws ec2 authorize-security-group-ingress \
        --group-id "${SG_ID}" \
        --protocol tcp \
        --port 443 \
        --cidr "${ip}" \
        --region "${AWS_REGION}" >/dev/null 2>&1 || true
done

# Add rules for each Cloudflare IPv6 range
for ip in $CF_IPV6; do
    # HTTP (port 80)
    aws ec2 authorize-security-group-ingress \
        --group-id "${SG_ID}" \
        --ip-permissions "IpProtocol=tcp,FromPort=80,ToPort=80,Ipv6Ranges=[{CidrIpv6=${ip}}]" \
        --region "${AWS_REGION}" >/dev/null 2>&1 || true
    
    # HTTPS (port 443)
    aws ec2 authorize-security-group-ingress \
        --group-id "${SG_ID}" \
        --ip-permissions "IpProtocol=tcp,FromPort=443,ToPort=443,Ipv6Ranges=[{CidrIpv6=${ip}}]" \
        --region "${AWS_REGION}" >/dev/null 2>&1 || true
done

echo "Security group rules configured"

echo ""
echo -e "${GREEN}Step 4: Getting Latest Ubuntu AMI${NC}"
# Get the latest Ubuntu 22.04 LTS AMI
AMI_ID=$(aws ec2 describe-images \
    --owners 099720109477 \
    --filters \
        "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*" \
        "Name=state,Values=available" \
    --query 'Images | sort_by(@, &CreationDate) | [-1].ImageId' \
    --output text \
    --region "${AWS_REGION}")

echo "Found Ubuntu AMI: ${AMI_ID}"

echo ""
echo -e "${GREEN}Step 5: Launching EC2 Instance${NC}"
# Launch EC2 instance
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "${AMI_ID}" \
    --instance-type "${INSTANCE_TYPE}" \
    --key-name "${KEY_NAME}" \
    --security-group-ids "${SG_ID}" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${INSTANCE_NAME}}]" \
    --region "${AWS_REGION}" \
    --output text \
    --query 'Instances[0].InstanceId')

echo "Instance launched: ${INSTANCE_ID}"
echo "Waiting for instance to be running..."

# Wait for instance to be running
aws ec2 wait instance-running \
    --instance-ids "${INSTANCE_ID}" \
    --region "${AWS_REGION}"

# Get instance details
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "${INSTANCE_ID}" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text \
    --region "${AWS_REGION}")

PUBLIC_DNS=$(aws ec2 describe-instances \
    --instance-ids "${INSTANCE_ID}" \
    --query 'Reservations[0].Instances[0].PublicDnsName' \
    --output text \
    --region "${AWS_REGION}")

echo ""
echo -e "${GREEN}=== EC2 Instance Setup Complete ===${NC}"
echo ""
echo -e "${YELLOW}Instance Details:${NC}"
echo "  Name: ${INSTANCE_NAME}"
echo "  Instance ID: ${INSTANCE_ID}"
echo "  Instance Type: ${INSTANCE_TYPE}"
echo "  Region: ${AWS_REGION}"
echo "  Public IP: ${PUBLIC_IP}"
echo "  Public DNS: ${PUBLIC_DNS}"
echo "  Security Group: ${SG_ID}"
echo "  SSH Key: ${KEY_PATH}"
echo ""
echo -e "${YELLOW}SSH Connection:${NC}"
echo "  ssh -i ${KEY_PATH} ubuntu@${PUBLIC_IP}"
echo ""
echo -e "${YELLOW}Security Configuration:${NC}"
echo "  - Port 22 (SSH): Open to 0.0.0.0/0"
echo "  - Port 80 (HTTP): Restricted to Cloudflare IPs"
echo "  - Port 443 (HTTPS): Restricted to Cloudflare IPs"
echo ""

# Save instance details to file
cat > "${INSTANCE_NAME}-details.txt" <<EOF
Instance Details
================
Name: ${INSTANCE_NAME}
Instance ID: ${INSTANCE_ID}
Instance Type: ${INSTANCE_TYPE}
Region: ${AWS_REGION}
Public IP: ${PUBLIC_IP}
Public DNS: ${PUBLIC_DNS}
Security Group: ${SG_ID}
SSH Key: ${KEY_PATH}
Created: $(date)

SSH Connection:
ssh -i ${KEY_PATH} ubuntu@${PUBLIC_IP}
EOF

echo "Instance details saved to: ${INSTANCE_NAME}-details.txt"