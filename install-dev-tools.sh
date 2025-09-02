#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Development Tools Installation Script ===${NC}"
echo ""

# Function to run command on remote EC2
run_remote() {
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "ubuntu@$EC2_IP" "$1"
}

# Function to run command with proper shell sourcing
run_remote_bash() {
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "ubuntu@$EC2_IP" "bash -c '$1'"
}

# Check if details file is provided
if [ $# -eq 0 ]; then
    echo "Usage: ./install-dev-tools.sh <instance-name-details.txt>"
    echo "Or provide connection details manually:"
    echo "  ./install-dev-tools.sh --ip <ip> --key <ssh-key-path>"
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

# Test SSH connection
echo ""
echo -e "${YELLOW}Testing SSH connection...${NC}"
if ! run_remote "echo 'Connection successful'"; then
    echo -e "${RED}Failed to connect to EC2 instance${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Starting installation of development tools...${NC}"

# Update system packages
echo ""
echo -e "${BLUE}Step 1: Updating system packages${NC}"
run_remote "sudo apt-get update -qq"
echo "System packages updated"

# Install essential build tools
echo ""
echo -e "${BLUE}Step 2: Installing build essentials${NC}"
run_remote "sudo apt-get install -y -qq build-essential curl git"
echo "Build essentials installed"

# Install uv (Python package manager)
echo ""
echo -e "${BLUE}Step 3: Installing uv (Python package manager)${NC}"
run_remote_bash "curl -LsSf https://astral.sh/uv/install.sh | sh"
run_remote_bash "source ~/.local/bin/env && uv --version"
echo "uv installed successfully"

# Install nvm (Node Version Manager)
echo ""
echo -e "${BLUE}Step 4: Installing nvm (Node Version Manager)${NC}"
run_remote_bash "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash"

# Source nvm and install latest LTS Node
echo "Installing Node.js LTS..."
run_remote_bash "export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\" && nvm install --lts && nvm use --lts && node --version"
echo "nvm and Node.js LTS installed successfully"

# Install Claude Code
echo ""
echo -e "${BLUE}Step 5: Installing Claude Code${NC}"
run_remote_bash "export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\" && npm install -g @anthropic-ai/claude-code"
echo "Claude Code installed successfully"

# Install Playwright with Chrome
echo ""
echo -e "${BLUE}Step 6: Installing Playwright with Chrome${NC}"
run_remote_bash "export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\" && npx playwright install chrome"
echo "Playwright with Chrome installed successfully"

# Verify installations
echo ""
echo -e "${BLUE}Step 7: Verifying installations${NC}"
echo ""
echo -e "${YELLOW}Installed versions:${NC}"

# Check uv
UV_VERSION=$(run_remote_bash "source ~/.local/bin/env && uv --version 2>/dev/null" || echo "Not found")
echo "  uv: $UV_VERSION"

# Check Node and npm
NODE_VERSION=$(run_remote_bash "export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\" && node --version 2>/dev/null" || echo "Not found")
NPM_VERSION=$(run_remote_bash "export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\" && npm --version 2>/dev/null" || echo "Not found")
echo "  Node.js: $NODE_VERSION"
echo "  npm: $NPM_VERSION"

# Check Claude Code
CLAUDE_VERSION=$(run_remote_bash "export NVM_DIR=\"\$HOME/.nvm\" && [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\" && claude --version 2>/dev/null" || echo "Not found")
echo "  Claude Code: $CLAUDE_VERSION"

# Create a helper script on the EC2 instance
echo ""
echo -e "${BLUE}Step 8: Creating helper script${NC}"
run_remote "cat > ~/setup-env.sh << 'EOF'
#!/bin/bash
# Source this file to set up the development environment

# Load uv
source ~/.local/bin/env

# Load nvm and use LTS Node
export NVM_DIR=\"\$HOME/.nvm\"
[ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"
[ -s \"\$NVM_DIR/bash_completion\" ] && . \"\$NVM_DIR/bash_completion\"

echo \"Development environment loaded:\"
echo \"  uv: \$(uv --version 2>/dev/null || echo 'not found')\"
echo \"  node: \$(node --version 2>/dev/null || echo 'not found')\"
echo \"  claude: \$(claude --version 2>/dev/null || echo 'not found')\"
EOF"

run_remote "chmod +x ~/setup-env.sh"
echo "Helper script created at ~/setup-env.sh"

echo ""
echo -e "${GREEN}=== Installation Complete ===${NC}"
echo ""
echo -e "${YELLOW}To use the installed tools, SSH into your instance and run:${NC}"
echo "  source ~/setup-env.sh"
echo ""
echo -e "${YELLOW}Or connect directly with:${NC}"
echo "  ssh -i $SSH_KEY ubuntu@$EC2_IP"
echo ""
echo -e "${YELLOW}Then you can use:${NC}"
echo "  - uv: Python package manager"
echo "  - nvm: Node version manager"
echo "  - node/npm: JavaScript runtime and package manager"
echo "  - claude: Claude Code CLI"
echo "  - playwright: Browser automation with Chrome"