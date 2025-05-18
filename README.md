# OllamaStack - Automated Ollama & Open WebUI Deployment Script

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Platform](https://img.shields.io/badge/platform-Ubuntu%20%7C%20Debian-orange.svg)
![Docker](https://img.shields.io/badge/docker-required-blue.svg)

## 🚀 Overview

**OllamaStack** is a comprehensive bash script that automates the installation and configuration of Ollama AI platform with Open WebUI, complete with SSL/TLS certificates, Docker containerization, and Nginx reverse proxy setup. This script provides a one-command solution to get your self-hosted AI chat interface up and running with professional-grade security and reliability.

## ✨ Features

- 🐳 **Automated Docker Installation**: Installs Docker and Docker Compose if not present
- 🔒 **SSL/TLS Certificate Management**: Automatic SSL certificate generation with Let's Encrypt
- 🌐 **Nginx Reverse Proxy**: Professional reverse proxy configuration with SSL termination
- 🤖 **Model Selection**: Interactive model selection from Ollama's library
- 🛡️ **Security Hardening**: Firewall configuration and security best practices
- 🔄 **Health Checks**: Built-in container health monitoring and retry logic
- 🎯 **Network Optimization**: Automatic fallback to host networking if needed
- 📊 **Comprehensive Logging**: Detailed logging and troubleshooting information
- 🔧 **Post-Installation Verification**: Complete system check after installation

## 🛠️ Prerequisites

- Ubuntu 18.04+ or Debian 10+ (64-bit)
- Root or sudo access
- Domain name pointing to your server's IP address
- Minimum 4GB RAM (8GB+ recommended for larger models)
- At least 20GB free disk space

## 📦 Installation

### Quick Start

```bash
# Download and run the script
wget https://raw.githubusercontent.com/shahinst/ollama-stack/install.sh
chmod +x install.sh
sudo ./install.sh
```

### Manual Installation

1. Clone this repository:
```bash
git clone https://github.com/shahinst/ollamastack/ollamastack.git
cd ollama-stack
```

2. Make the script executable:
```bash
chmod +x install.sh
```

3. Run the installation script:
```bash
sudo ./install.sh
```

## 🎯 Usage

The script will prompt you for:

1. **Domain Name**: Your fully qualified domain name (e.g., `ai.example.com`)
2. **AI Model**: Choose from Ollama's model library (visit [ollama.com/search](https://ollama.com/search))

### Available Models Examples:
- `llama3:8b` - Meta's Llama 3 (8B parameters)
- `deepseek-r1:7b` - DeepSeek R1 (7B parameters)
- `mixtral:8x7b` - Mixtral 8x7B Instruct
- `codellama:7b` - Code Llama (7B parameters)
- `mistral:7b` - Mistral 7B Instruct

## 🔧 Post-Installation

After successful installation, you can:

### Access Your AI Interface
- Visit `https://your-domain.com` to access Open WebUI
- First visit will require creating an admin account

### Manage Services
```bash
# Navigate to service directory
cd /opt/ollama-webui

# Stop services
docker compose down

# Start services
docker compose up -d

# View logs
docker compose logs

# Restart services
docker compose restart
```

### Manage Models
```bash
# List installed models
docker exec ollama ollama list

# Download new models
docker exec ollama ollama pull model-name

# Remove models
docker exec ollama ollama rm model-name
```

## 🐛 Troubleshooting

### Common Issues

**1. Container Connectivity Issues**
```bash
# Check container status
docker ps

# Test API connectivity
docker exec open-webui curl -s http://ollama:11434/api/tags

# Restart with host networking
# The script automatically falls back to this if needed
```

**2. SSL Certificate Problems**
```bash
# Manually request certificate
sudo certbot --nginx -d your-domain.com

# Check certificate status
sudo certbot certificates
```

**3. Port Conflicts**
```bash
# Check port usage
sudo lsof -i :8080
sudo lsof -i :11434

# Stop conflicting services if needed
sudo systemctl stop service-name
```

**4. Model Download Issues**
```bash
# Check Ollama logs
docker logs ollama

# Manually download model
docker exec ollama ollama pull model-name
```

### Log Locations
- Installation logs: `/opt/ollama-webui/compose.log`
- Ollama logs: `docker logs ollama`
- Open WebUI logs: `docker logs open-webui`
- Nginx logs: `/var/log/nginx/`

## 🏗️ Architecture

```
Internet → Nginx (SSL/443) → Open WebUI (8080) → Ollama (11434)
                ↓
         Let's Encrypt SSL
```

## 🔐 Security Features

- **SSL/TLS Encryption**: End-to-end encryption with Let's Encrypt
- **Firewall Configuration**: Automated UFW rules for required ports
- **Container Isolation**: Docker network isolation
- **Authentication**: Open WebUI built-in authentication system
- **Reverse Proxy**: Nginx handles SSL termination and security headers

## 📋 System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | 2 cores | 4+ cores |
| RAM | 4GB | 8GB+ |
| Storage | 20GB | 50GB+ |
| Network | 10Mbps | 100Mbps+ |

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Ollama](https://ollama.ai/) - For the amazing local AI platform
- [Open WebUI](https://github.com/open-webui/open-webui) - For the beautiful web interface
- [Docker](https://docker.com/) - For containerization technology
- [Let's Encrypt](https://letsencrypt.org/) - For free SSL certificates

## 📞 Support

If you encounter any issues or have questions:

1. Check the [Troubleshooting](#-troubleshooting) section
2. Search existing [Issues](https://github.com/shahinst/ollamastack/issues)
3. Create a new [Issue](https://github.com/shahinst/ollamastack/issues/new) with:
   - Your OS version
   - Error messages
   - Relevant log outputs

## 🔮 Roadmap

- [ ] Support for additional Linux distributions (CentOS, RHEL)
- [ ] GPU support configuration
- [ ] Backup and restore functionality
- [ ] Multi-user management
- [ ] Custom model management interface
- [ ] Monitoring and metrics dashboard
- [ ] Automatic updates mechanism

---

<div align="center">

**⭐ Star this repository if you find it helpful!**

Made with ❤️ for the open-source AI community

</div>
