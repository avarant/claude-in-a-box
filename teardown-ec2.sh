#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== EC2 Instance Teardown Script ===${NC}"
echo ""

# Check if details file is provided
if [ $# -eq 0 ]; then
    echo "Usage: ./teardown-ec2.sh <instance-name-details.txt>"
    echo "Or provide instance ID and region manually:"
    echo "  ./teardown-ec2.sh --instance-id <id> --region <region>"
    exit 1
fi

# Parse arguments
if [ "$1" == "--instance-id" ]; then
    INSTANCE_ID="$2"
    REGION="$4"
    echo "Manual mode - Instance ID: $INSTANCE_ID, Region: $REGION"
else
    # Read from details file
    DETAILS_FILE="$1"
    if [ ! -f "$DETAILS_FILE" ]; then
        echo -e "${RED}Error: Details file not found: $DETAILS_FILE${NC}"
        exit 1
    fi
    
    INSTANCE_ID=$(grep "Instance ID:" "$DETAILS_FILE" | cut -d' ' -f3)
    REGION=$(grep "Region:" "$DETAILS_FILE" | cut -d' ' -f2)
    INSTANCE_NAME=$(grep "Name:" "$DETAILS_FILE" | head -1 | cut -d' ' -f2)
    SG_ID=$(grep "Security Group:" "$DETAILS_FILE" | cut -d' ' -f3)
    KEY_PATH=$(grep "SSH Key:" "$DETAILS_FILE" | cut -d' ' -f3)
    KEY_NAME=$(basename "$KEY_PATH" .pem)
    
    echo "Loaded configuration from: $DETAILS_FILE"
    echo "  Instance: $INSTANCE_NAME ($INSTANCE_ID)"
    echo "  Region: $REGION"
    echo "  Security Group: $SG_ID"
fi

echo ""
read -p "Are you sure you want to terminate this instance and clean up resources? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Teardown cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Starting teardown process...${NC}"

# Terminate EC2 instance
echo -e "${GREEN}Step 1: Terminating EC2 instance${NC}"
aws ec2 terminate-instances \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION" >/dev/null

echo "Instance termination initiated: $INSTANCE_ID"
echo "Waiting for instance to terminate..."

aws ec2 wait instance-terminated \
    --instance-ids "$INSTANCE_ID" \
    --region "$REGION"

echo "Instance terminated successfully"

# Delete security group (if provided)
if [ ! -z "$SG_ID" ]; then
    echo ""
    echo -e "${GREEN}Step 2: Deleting Security Group${NC}"
    # Wait a bit for the instance to fully release the security group
    sleep 5
    
    aws ec2 delete-security-group \
        --group-id "$SG_ID" \
        --region "$REGION" 2>/dev/null && \
        echo "Security group deleted: $SG_ID" || \
        echo "Could not delete security group (may be in use or already deleted)"
fi

# Delete key pair from AWS
if [ ! -z "$KEY_NAME" ]; then
    echo ""
    echo -e "${GREEN}Step 3: Deleting Key Pair from AWS${NC}"
    aws ec2 delete-key-pair \
        --key-name "$KEY_NAME" \
        --region "$REGION" 2>/dev/null && \
        echo "Key pair deleted from AWS: $KEY_NAME" || \
        echo "Could not delete key pair (may not exist)"
fi

# Clean up local files
echo ""
echo -e "${GREEN}Step 4: Local Cleanup${NC}"
if [ ! -z "$KEY_PATH" ] && [ -f "$KEY_PATH" ]; then
    rm -f "$KEY_PATH" "${KEY_PATH}.pub"
    echo "Deleted local SSH keys"
fi

if [ ! -z "$DETAILS_FILE" ] && [ -f "$DETAILS_FILE" ]; then
    # Archive the details file instead of deleting
    mv "$DETAILS_FILE" "${DETAILS_FILE}.terminated-$(date +%Y%m%d-%H%M%S)"
    echo "Archived instance details file"
fi

echo ""
echo -e "${GREEN}=== Teardown Complete ===${NC}"
echo "All resources have been cleaned up successfully."