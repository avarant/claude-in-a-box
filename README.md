# Claude in a Box 🤖

A template repository for quickly spinning up AWS EC2 instances with Claude Code CLI and development tools pre-installed. Perfect for creating isolated development environments with AI assistance.

## 🚀 Quick Start

1. Clone this repository:
```bash
git clone https://github.com/avarant/claude-in-a-box.git
cd claude-in-a-box
```

2. Launch an EC2 instance:
```bash
./setup-ec2.sh
```
You'll be prompted for:
- Instance name
- AWS region (default: us-west-2)
- Instance type (default: t3.medium)

3. Install development tools on the instance:
```bash
./install-dev-tools.sh <instance-name>-details.txt
```

4. SSH into your instance:
```bash
ssh -i ./<instance-name>-key-*.pem ubuntu@<public-ip>
```

5. Start using Claude:
```bash
source ~/setup-env.sh
claude --help
```

## 📋 Prerequisites

- **AWS CLI** configured with appropriate credentials
- **SSH** client installed
- **Bash** shell (macOS/Linux/WSL)
- AWS account with permissions to:
  - Create EC2 instances
  - Create security groups
  - Import SSH key pairs

## 🛠️ What Gets Installed

The setup creates an Ubuntu 22.04 LTS instance with:

- **[Claude Code CLI](https://claude.ai/code)** - AI coding assistant
- **[uv](https://github.com/astral-sh/uv)** - Fast Python package manager
- **[nvm](https://github.com/nvm-sh/nvm)** - Node Version Manager
- **Node.js LTS** - JavaScript runtime
- **Build essentials** - Compilers and development tools

## 🔒 Security Configuration

The instance is configured with:
- **SSH (Port 22)**: Open to public (0.0.0.0/0)
- **HTTP (Port 80)**: Restricted to Cloudflare IPs only
- **HTTPS (Port 443)**: Restricted to Cloudflare IPs only

This configuration is ideal for web applications behind Cloudflare while maintaining SSH access.

## 📁 Repository Scripts

### `setup-ec2.sh`
Launches a new EC2 instance with proper security configuration:
- Generates SSH keypair locally
- Creates security group with Cloudflare IP restrictions
- Launches Ubuntu 22.04 instance
- Saves connection details for easy access

### `install-dev-tools.sh`
Installs development tools on the EC2 instance:
```bash
./install-dev-tools.sh <instance-name>-details.txt
```

### `scp-helper.sh`
Simplifies file transfers to/from the instance:
```bash
# Upload file
./scp-helper.sh upload local-file.txt

# Download file
./scp-helper.sh download remote-file.txt

# List remote directory
./scp-helper.sh list /home/ubuntu/

# Upload directory recursively
./scp-helper.sh upload -r ./my-project/ project/
```

### `teardown-ec2.sh`
Cleans up all resources when done:
```bash
./teardown-ec2.sh <instance-name>-details.txt
```
This will:
- Terminate the EC2 instance
- Delete the security group
- Remove the SSH key pair from AWS
- Archive local files

## 💰 Cost Considerations

- **t3.medium** instance: ~$0.0416/hour (varies by region)
- **Storage**: 8GB gp3 volume included
- **Data transfer**: Check AWS pricing for your region
- **Remember to terminate instances when not in use!**

## 🎯 Use Cases

This template is perfect for:
- **Isolated development environments** with AI assistance
- **Learning and experimentation** with Claude Code CLI
- **Quick prototyping** with AI pair programming
- **Running Claude Code** in a cloud environment
- **Team development** with consistent environments

## 📝 Instance Management

### Starting a stopped instance
```bash
aws ec2 start-instances --instance-ids <instance-id> --region <region>
```

### Stopping an instance (preserves data)
```bash
aws ec2 stop-instances --instance-ids <instance-id> --region <region>
```

### Getting instance status
```bash
aws ec2 describe-instances --instance-ids <instance-id> --region <region>
```

## 🔧 Customization

### Changing default region
Edit `setup-ec2.sh` and modify the default value:
```bash
AWS_REGION=${AWS_REGION:-us-west-2}  # Change us-west-2 to your preferred region
```

### Changing default instance type
Edit `setup-ec2.sh` and modify the default value:
```bash
INSTANCE_TYPE=${INSTANCE_TYPE:-t3.medium}  # Change t3.medium to your preferred type
```

### Adding more security group rules
Modify the security group section in `setup-ec2.sh` to add additional ports or IP ranges.

## 🐛 Troubleshooting

### SSH connection refused
- Wait 60 seconds after instance launch for SSH to be ready
- Verify security group allows port 22 from your IP
- Check the instance is in "running" state

### Claude command not found
Run the environment setup script:
```bash
source ~/setup-env.sh
```

### Permission denied on scripts
Make scripts executable:
```bash
chmod +x *.sh
```

### AWS CLI not configured
Configure AWS credentials:
```bash
aws configure
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## ⚠️ Important Notes

- **Always terminate or stop instances when not in use** to avoid unnecessary charges
- **Keep your SSH keys secure** - never commit them to version control
- **Monitor your AWS billing** to avoid surprises
- **Use appropriate instance types** for your workload

## 📞 Support

For issues or questions:
- Open an issue on [GitHub](https://github.com/avarant/claude-in-a-box/issues)
- Check AWS documentation for EC2-specific problems
- Visit [Claude Code documentation](https://docs.anthropic.com/en/docs/claude-code) for CLI help

---

Built with ❤️ to make AI-assisted development accessible in the cloud