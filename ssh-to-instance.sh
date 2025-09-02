#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== SSH Connection Script ===${NC}"
echo ""

# Check if details file is provided
if [ $# -eq 0 ]; then
    echo "Usage: ./ssh-to-instance.sh <instance-name-details.txt>"
    echo "Or provide connection details manually:"
    echo "  ./ssh-to-instance.sh --ip <ip> --key <ssh-key-path>"
    exit 1
fi

# Parse arguments
if [ "$1" == "--ip" ]; then
    EC2_IP="$2"
    SSH_KEY="$4"
    echo "Manual mode - IP: $EC2_IP, SSH Key: $SSH_KEY"
else
    # Read from details file
    DETAILS_FILE="$1"
    if [ ! -f "$DETAILS_FILE" ]; then
        echo -e "${RED}Error: Details file not found: $DETAILS_FILE${NC}"
        exit 1
    fi
    
    EC2_IP=$(grep "Public IP:" "$DETAILS_FILE" | cut -d' ' -f3)
    SSH_KEY=$(grep "SSH Key:" "$DETAILS_FILE" | cut -d' ' -f3)
    INSTANCE_NAME=$(grep "Name:" "$DETAILS_FILE" | head -1 | cut -d' ' -f2)
    
    echo "Loaded configuration from: $DETAILS_FILE"
    echo "  Instance: $INSTANCE_NAME"
    echo "  IP: $EC2_IP"
fi

# Check if SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}Error: SSH key not found: $SSH_KEY${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Connecting to EC2 instance...${NC}"
echo -e "${YELLOW}To load development tools after connecting, run:${NC}"
echo "  source ~/setup-env.sh"
echo ""

# Connect to the instance
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "ubuntu@$EC2_IP"