#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to show usage
show_usage() {
    echo -e "${BLUE}=== SCP Helper for EC2 Instance ===${NC}"
    echo ""
    echo "Usage:"
    echo "  ./scp-helper.sh upload <local-file> [remote-path]"
    echo "  ./scp-helper.sh download <remote-file> [local-path]"
    echo "  ./scp-helper.sh list [remote-path]"
    echo ""
    echo "Options:"
    echo "  -d, --details <file>   Use specific instance details file (default: latest *-details.txt)"
    echo "  -r, --recursive        Copy directories recursively"
    echo "  -v, --verbose          Show detailed transfer information"
    echo ""
    echo "Examples:"
    echo "  ./scp-helper.sh upload myfile.txt"
    echo "  ./scp-helper.sh upload ./src /home/ubuntu/project/"
    echo "  ./scp-helper.sh download /home/ubuntu/data.csv ./downloads/"
    echo "  ./scp-helper.sh download /home/ubuntu/logs/ ./ -r"
    echo "  ./scp-helper.sh list /home/ubuntu/"
    exit 1
}

# Parse command line arguments
COMMAND=""
SOURCE=""
DEST=""
DETAILS_FILE=""
RECURSIVE=""
VERBOSE=""
ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--details)
            DETAILS_FILE="$2"
            shift 2
            ;;
        -r|--recursive)
            RECURSIVE="-r"
            shift
            ;;
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        upload|download|list)
            COMMAND="$1"
            shift
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# Check if command is provided
if [ -z "$COMMAND" ]; then
    show_usage
fi

# Find details file if not specified
if [ -z "$DETAILS_FILE" ]; then
    # Find the most recent details file
    DETAILS_FILE=$(ls -t *-details.txt 2>/dev/null | grep -v ".terminated-" | head -1)
    if [ -z "$DETAILS_FILE" ]; then
        echo -e "${RED}Error: No instance details file found${NC}"
        echo "Please specify a details file with -d option or ensure a *-details.txt file exists"
        exit 1
    fi
fi

# Check if details file exists
if [ ! -f "$DETAILS_FILE" ]; then
    echo -e "${RED}Error: Details file not found: $DETAILS_FILE${NC}"
    exit 1
fi

# Extract connection information
EC2_IP=$(grep "Public IP:" "$DETAILS_FILE" | cut -d' ' -f3)
SSH_KEY=$(grep "SSH Key:" "$DETAILS_FILE" | cut -d' ' -f3)
INSTANCE_NAME=$(grep "Name:" "$DETAILS_FILE" | head -1 | cut -d' ' -f2)

# Verify SSH key exists
if [ ! -f "$SSH_KEY" ]; then
    echo -e "${RED}Error: SSH key not found: $SSH_KEY${NC}"
    exit 1
fi

echo -e "${GREEN}Using instance: ${INSTANCE_NAME} (${EC2_IP})${NC}"

# Common SCP options
SCP_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no $RECURSIVE $VERBOSE"

# Execute command
case $COMMAND in
    upload)
        SOURCE="${ARGS[0]}"
        DEST="${ARGS[1]:-/home/ubuntu/}"
        
        if [ -z "$SOURCE" ]; then
            echo -e "${RED}Error: Please specify a local file/directory to upload${NC}"
            exit 1
        fi
        
        if [ ! -e "$SOURCE" ]; then
            echo -e "${RED}Error: Local file/directory not found: $SOURCE${NC}"
            exit 1
        fi
        
        # If destination doesn't start with /, prepend /home/ubuntu/
        if [[ ! "$DEST" =~ ^/ ]]; then
            DEST="/home/ubuntu/$DEST"
        fi
        
        echo -e "${YELLOW}Uploading: $SOURCE -> ubuntu@$EC2_IP:$DEST${NC}"
        
        if scp $SCP_OPTS "$SOURCE" "ubuntu@$EC2_IP:$DEST"; then
            echo -e "${GREEN}Upload successful!${NC}"
            
            # Show uploaded file details
            if [ -z "$RECURSIVE" ]; then
                ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "ubuntu@$EC2_IP" "ls -lah '$DEST' 2>/dev/null || ls -lah '$DEST$(basename $SOURCE)' 2>/dev/null"
            else
                echo "Uploaded directory contents:"
                ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "ubuntu@$EC2_IP" "ls -lah '$DEST'"
            fi
        else
            echo -e "${RED}Upload failed${NC}"
            exit 1
        fi
        ;;
        
    download)
        SOURCE="${ARGS[0]}"
        DEST="${ARGS[1]:-.}"
        
        if [ -z "$SOURCE" ]; then
            echo -e "${RED}Error: Please specify a remote file/directory to download${NC}"
            exit 1
        fi
        
        # If source doesn't start with /, prepend /home/ubuntu/
        if [[ ! "$SOURCE" =~ ^/ ]]; then
            SOURCE="/home/ubuntu/$SOURCE"
        fi
        
        echo -e "${YELLOW}Downloading: ubuntu@$EC2_IP:$SOURCE -> $DEST${NC}"
        
        # Check if remote file exists
        if ! ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "ubuntu@$EC2_IP" "test -e '$SOURCE'"; then
            echo -e "${RED}Error: Remote file/directory not found: $SOURCE${NC}"
            exit 1
        fi
        
        if scp $SCP_OPTS "ubuntu@$EC2_IP:$SOURCE" "$DEST"; then
            echo -e "${GREEN}Download successful!${NC}"
            
            # Show downloaded file details
            if [ -d "$DEST" ]; then
                ls -lah "$DEST/$(basename $SOURCE)"
            else
                ls -lah "$DEST"
            fi
        else
            echo -e "${RED}Download failed${NC}"
            exit 1
        fi
        ;;
        
    list)
        REMOTE_PATH="${ARGS[0]:-/home/ubuntu/}"
        
        # If path doesn't start with /, prepend /home/ubuntu/
        if [[ ! "$REMOTE_PATH" =~ ^/ ]]; then
            REMOTE_PATH="/home/ubuntu/$REMOTE_PATH"
        fi
        
        echo -e "${YELLOW}Listing contents of: $REMOTE_PATH${NC}"
        echo ""
        
        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "ubuntu@$EC2_IP" "ls -lah '$REMOTE_PATH'" || {
            echo -e "${RED}Error: Could not list directory${NC}"
            exit 1
        }
        ;;
        
    *)
        echo -e "${RED}Error: Unknown command: $COMMAND${NC}"
        show_usage
        ;;
esac