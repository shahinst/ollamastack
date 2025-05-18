#!/bin/bash

# ANSI colors for prettier output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display information messages
info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

# Function to display success messages
success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to display warning messages
warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to display error messages
error() {
  echo -e "${RED}[ERROR]${NC} $1"
  if [ "$2" = "exit" ]; then
    exit 1
  fi
}

# Function to check if a package is installed
check_package() {
  if ! dpkg -l | grep -q "$1"; then
    return 1
  fi
  return 0
}

# Function to install a package if not already installed
install_package() {
  if ! check_package "$1"; then
    info "Installing $1..."
    apt-get install -y "$1" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
      error "Error installing $1" "exit"
    fi
    success "$1 installed successfully."
  else
    info "$1 is already installed."
  fi
}

# Function to check if a port is available
check_port() {
  if lsof -Pi :$1 -sTCP:LISTEN -t >/dev/null; then
    return 0
  fi
  return 1
}

# Function to validate domain name
validate_domain() {
  local domain_regex="^([a-zA-Z0-9][-a-zA-Z0-9]*\.)+[a-zA-Z]{2,}$"
  if [[ "$1" =~ $domain_regex ]]; then
    return 0
  fi
  return 1
}

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  error "This script must be run as root (with sudo)." "exit"
fi

clear
echo "=========================================================="
echo "    Installing Ollama, Docker, and Open WebUI with SSL    "
echo "                  Digicloud Company                       "
echo "=========================================================="
echo -e "\e[0m"
echo "🌐 https://digicloud.host"
echo "🌐 https://oxincloud.net"
echo "🔗 GitHub: https://github.com/shahinst"
echo

# Get domain name from user
while true; do
  read -p "Please enter your domain name (e.g., example.com): " DOMAIN
  if validate_domain "$DOMAIN"; then
    break
  else
    error "Invalid domain. Please try again."
  fi
done

# Get model name from user
echo ""
echo "Please choose a model to install from Ollama library."
echo "You can find available models at: https://ollama.com/search"
read -p "Enter model name (e.g., deepseek-r1:7b, llama3:8b, mixtral:8x7b): " MODEL_NAME

if [ -z "$MODEL_NAME" ]; then
  MODEL_NAME="deepseek-r1:7b"
  info "No model specified, using default model: $MODEL_NAME"
else
  info "Selected model: $MODEL_NAME"
fi

# Check DNS for domain
info "Checking DNS for domain $DOMAIN..."
if ! host "$DOMAIN" > /dev/null 2>&1; then
  warning "DNS record for $DOMAIN not found. Make sure the domain points to this server's IP address."
  read -p "Do you want to continue? (y/n): " continue_choice
  if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
    error "Script execution aborted." "exit"
  fi
fi

# Update server
info "Updating package lists..."
apt-get update > /dev/null 2>&1 || error "Error updating package lists" "exit"

# Install required tools
info "Installing required packages..."
REQUIRED_PACKAGES="apt-transport-https ca-certificates curl software-properties-common gnupg lsof net-tools dnsutils certbot python3-certbot-nginx"
for package in $REQUIRED_PACKAGES; do
  install_package "$package"
done

# Install and configure Nginx
info "Installing and configuring Nginx..."
install_package "nginx"

# Enable Nginx
if ! systemctl is-active --quiet nginx; then
  systemctl enable nginx > /dev/null 2>&1
  systemctl start nginx > /dev/null 2>&1
  if ! systemctl is-active --quiet nginx; then
    error "Error starting Nginx" "exit"
  fi
fi
success "Nginx started successfully."

# Install Docker
info "Installing Docker..."
if ! command -v docker &> /dev/null; then
  curl -fsSL https://get.docker.com -o get-docker.sh
  if [ ! -f get-docker.sh ]; then
    error "Error downloading Docker installation script" "exit"
  fi
  
  sh get-docker.sh > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    error "Error installing Docker" "exit"
  fi
  
  systemctl enable docker > /dev/null 2>&1
  systemctl start docker > /dev/null 2>&1
  if ! systemctl is-active --quiet docker; then
    error "Error starting Docker" "exit"
  fi
  
  rm get-docker.sh
  success "Docker installed and started successfully."
else
  info "Docker is already installed."
fi

# Install Docker Compose
info "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
  install_package "docker-compose-plugin"
  if ! docker compose version &> /dev/null; then
    error "Error installing Docker Compose" "exit"
  fi
  success "Docker Compose installed successfully."
else
  info "Docker Compose is already installed."
fi

# Create directory for services
info "Setting up service directory..."
mkdir -p /opt/ollama-webui
cd /opt/ollama-webui

# Create Docker network
info "Creating Docker network for Ollama and Open WebUI..."
docker network create ollama-webui-network > /dev/null 2>&1 || info "Docker network already exists."

# Create docker-compose file for Ollama and Open WebUI
info "Configuring Ollama and Open WebUI..."
cat > /opt/ollama-webui/docker-compose.yml << EOF
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    volumes:
      - ollama-data:/root/.ollama
    environment:
      - OLLAMA_HOST=0.0.0.0:11434
    ports:
      - 11434:11434
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434/"]
      interval: 10s
      timeout: 15s
      retries: 10
    restart: unless-stopped
    networks:
      - ollama-webui-network

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    volumes:
      - open-webui-data:/app/backend/data
    environment:
      - OLLAMA_API_BASE_URL=http://ollama:11434
      - WEBUI_AUTH=true
      - WEBUI_UID=1000
      - WEBUI_GID=1000
    ports:
      - 8080:8080
    depends_on:
      ollama:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - ollama-webui-network

networks:
  ollama-webui-network:
    external: true
    name: ollama-webui-network

volumes:
  ollama-data:
    driver: local
  open-webui-data:
    driver: local
EOF

# Stop any existing Ollama system service
if systemctl is-active --quiet ollama; then
  info "Stopping existing Ollama system service..."
  systemctl stop ollama > /dev/null 2>&1
  systemctl disable ollama > /dev/null 2>&1
fi

# Start Ollama and Open WebUI
info "Starting Ollama and Open WebUI..."
docker compose down > /dev/null 2>&1
docker compose up -d > compose.log 2>&1

if [ $? -ne 0 ]; then
  error "Error starting services. Check compose.log for details."
  cat compose.log
  docker compose logs
  warning "Attempting fallback with host network mode..."
  
  # Update docker-compose with host network
  cat > /opt/ollama-webui/docker-compose.yml << EOF
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    volumes:
      - ollama-data:/root/.ollama
    environment:
      - OLLAMA_HOST=0.0.0.0:11434
    ports:
      - 11434:11434
    restart: unless-stopped
    network_mode: host

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    volumes:
      - open-webui-data:/app/backend/data
    environment:
      - OLLAMA_API_BASE_URL=http://127.0.0.1:11434
      - WEBUI_AUTH=true
      - WEBUI_UID=1000
      - WEBUI_GID=1000
    ports:
      - 8080:8080
    restart: unless-stopped
    network_mode: host

volumes:
  ollama-data:
    driver: local
  open-webui-data:
    driver: local
EOF

  info "Restarting services with host network mode..."
  docker compose down > /dev/null 2>&1
  docker compose up -d > compose.log 2>&1

  if [ $? -ne 0 ]; then
    error "Fallback failed. Please check logs and troubleshoot manually."
    cat compose.log
    docker compose logs
    read -p "Do you want to continue? (y/n): " continue_choice
    if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
      error "Script execution aborted." "exit"
    fi
  else
    success "Services started successfully with host network mode."
  fi
else
  success "Ollama and Open WebUI started successfully."
fi

# Check Ollama container status
sleep 5
info "Checking Ollama container status..."
if ! docker ps | grep -q "ollama"; then
  error "Ollama container is not running."
  docker logs ollama
  read -p "Do you want to continue? (y/n): " continue_choice
  if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
    error "Script execution aborted." "exit"
  fi
else
  success "Ollama container is running."
fi

# Check Open WebUI container status
info "Checking Open WebUI container status..."
if ! docker ps | grep -q "open-webui"; then
  error "Open WebUI container is not running."
  docker logs open-webui
  read -p "Do you want to continue? (y/n): " continue_choice
  if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
    error "Script execution aborted." "exit"
  fi
else
  success "Open WebUI container is running."
fi

# Verify Ollama API is accessible with retry logic
info "Checking Ollama API accessibility with retries..."
attempts=0
max_attempts=5
while [ $attempts -lt $max_attempts ]; do
  if docker exec open-webui curl -s http://ollama:11434/api/tags > /dev/null; then
    success "Ollama API is accessible from Open WebUI."
    break
  else
    warning "Attempt $((attempts + 1))/$max_attempts: Open WebUI cannot connect to Ollama API."
    sleep 5
    attempts=$((attempts + 1))
  fi
done

if [ $attempts -eq $max_attempts ]; then
  error "Open WebUI cannot connect to Ollama API after $max_attempts attempts."
  docker logs ollama
  docker logs open-webui
  warning "Attempting fallback with host network mode..."
  
  # Update docker-compose with host network
  cat > /opt/ollama-webui/docker-compose.yml << EOF
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    volumes:
      - ollama-data:/root/.ollama
    environment:
      - OLLAMA_HOST=0.0.0.0:11434
    ports:
      - 11434:11434
    restart: unless-stopped
    network_mode: host

  open-webui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    volumes:
      - open-webui-data:/app/backend/data
    environment:
      - OLLAMA_API_BASE_URL=http://127.0.0.1:11434
      - WEBUI_AUTH=true
      - WEBUI_UID=1000
      - WEBUI_GID=1000
    ports:
      - 8080:8080
    restart: unless-stopped
    network_mode: host

volumes:
  ollama-data:
    driver: local
  open-webui-data:
    driver: local
EOF

  info "Restarting services with host network mode..."
  docker compose down > /dev/null 2>&1
  docker compose up -d > compose.log 2>&1
  sleep 5
  
  if docker exec open-webui curl -s http://127.0.0.1:11434/api/tags > /dev/null; then
    success "Ollama API is accessible with host network mode."
  else
    error "Fallback failed. Please check logs and troubleshoot manually."
    docker logs ollama
    docker logs open-webui
    read -p "Do you want to continue? (y/n): " continue_choice
    if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
      error "Script execution aborted." "exit"
    fi
  fi
fi

# Download the specified model
info "Downloading $MODEL_NAME model (this may take several minutes)..."
docker exec ollama ollama pull $MODEL_NAME > /dev/null
if [ $? -ne 0 ]; then
  error "Error downloading $MODEL_NAME model"
  read -p "Do you want to continue? (y/n): " continue_choice
  if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
    error "Script execution aborted." "exit"
  fi
else
  success "$MODEL_NAME model downloaded successfully."
fi

# Initialize model list
info "Initializing Ollama model list..."
docker exec ollama ollama list > /dev/null 2>&1 || warning "Failed to initialize Ollama model list. This may cause issues in Open WebUI."

# Configure Nginx for Open WebUI
info "Configuring Nginx for Open WebUI..."
cat > /etc/nginx/sites-available/$DOMAIN << EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
EOF

# Enable Nginx site
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default > /dev/null 2>&1

# Check Nginx configuration
nginx -t > /dev/null 2>&1
if [ $? -ne 0 ]; then
  error "Error in Nginx configuration"
  nginx -t
  read -p "Do you want to continue? (y/n): " continue_choice
  if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
    error "Script execution aborted." "exit"
  fi
else
  systemctl reload nginx > /dev/null 2>&1
  success "Nginx configuration completed successfully."
fi

# Install SSL certificate with Certbot
info "Installing SSL certificate for domain $DOMAIN..."
certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN > /dev/null 2>&1

if [ $? -ne 0 ]; then
  error "Error installing SSL certificate. Trying alternate method..."
  
  # Stop nginx before using standalone
  systemctl stop nginx > /dev/null 2>&1
  
  certbot --standalone -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN > /dev/null 2>&1
  
  if [ $? -ne 0 ]; then
    error "Error installing SSL certificate with alternate method."
    warning "Continuing without SSL. You can install SSL later with the following command:"
    echo "sudo certbot --nginx -d $DOMAIN"
  else
    success "SSL certificate installed successfully with alternate method."
    
    # Start nginx again
    systemctl start nginx > /dev/null 2>&1
    
    # Update Nginx configuration
    cat > /etc/nginx/sites-available/$DOMAIN << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
}
EOF
    systemctl reload nginx > /dev/null 2>&1
  fi
else
  success "SSL certificate installed successfully."
fi

# Check UFW status (if installed) and allow needed ports
if command -v ufw &> /dev/null; then
  info "Checking firewall settings..."
  if ufw status | grep -q "active"; then
    ufw allow 80/tcp > /dev/null 2>&1
    ufw allow 443/tcp > /dev/null 2>&1
    ufw allow 11434/tcp > /dev/null 2>&1
    ufw allow 8080/tcp > /dev/null 2>&1
    success "Firewall updated to allow necessary ports."
  fi
fi

# Final system check
echo ""
echo "=========================================================="
echo "             Final System Check"
echo "=========================================================="

# Check Ollama container
info "Checking Ollama container..."
if docker ps | grep -q "ollama"; then
  success "Ollama container is active."
else
  error "Ollama container is not active. Restarting..."
  docker compose restart ollama > /dev/null 2>&1
  sleep 3
  if docker ps | grep -q "ollama"; then
    success "Ollama container restarted successfully."
  else
    error "Ollama container restart failed."
  fi
fi

# Check Ollama API
info "Checking Ollama API..."
if curl -s http://localhost:11434/api/tags > /dev/null; then
  success "Ollama API is accessible."
else
  error "Ollama API is not accessible."
fi

# Check for the specified model
info "Checking for $MODEL_NAME model..."
if docker exec ollama ollama list | grep -q "$MODEL_NAME"; then
  success "$MODEL_NAME model is present."
else
  error "$MODEL_NAME model not found. Re-downloading..."
  docker exec ollama ollama pull $MODEL_NAME > /dev/null
  if docker exec ollama ollama list | grep -q "$MODEL_NAME"; then
    success "$MODEL_NAME model downloaded successfully."
  else
    error "Re-downloading $MODEL_NAME model failed."
  fi
fi

# Check Open WebUI container
info "Checking Open WebUI container..."
if docker ps | grep -q "open-webui"; then
  success "Open WebUI container is running."
else
  error "Open WebUI container is not running. Restarting..."
  docker compose restart open-webui > /dev/null 2>&1
  sleep 5
  if docker ps | grep -q "open-webui"; then
    success "Open WebUI container restarted successfully."
  else
    error "Open WebUI container restart failed."
  fi
fi

# Display access information
echo ""
echo "=========================================================="
echo "             Access Information"
echo "=========================================================="
echo -e "${GREEN}Ollama and Open WebUI have been installed.${NC}"
echo ""
echo "You can access Open WebUI through your domain:"
echo -e "${BLUE}https://$DOMAIN${NC}"
echo ""
echo "Ollama service is accessible via API at:"
echo -e "${BLUE}http://localhost:11434${NC}"
echo ""
echo "Downloaded model:"
echo -e "${BLUE}$MODEL_NAME${NC}"
echo ""
echo "To manage services, use the following commands:"
echo -e "${YELLOW}cd /opt/ollama-webui${NC}"
echo -e "${YELLOW}docker compose down${NC} # Stop services"
echo -e "${YELLOW}docker compose up -d${NC} # Restart services"
echo -e "${YELLOW}docker compose logs${NC} # View logs"
echo ""
echo "To manage Ollama models, use:"
echo -e "${YELLOW}docker exec ollama ollama list${NC} # List installed models"
echo -e "${YELLOW}docker exec ollama ollama pull [model]${NC} # Download new model"
echo ""
echo "If you experience connectivity issues between Open WebUI and Ollama:"
echo -e "${BLUE}1. Verify both containers are running:${NC}"
echo -e "${YELLOW}docker ps${NC}"
echo ""
echo -e "${BLUE}2. Check Docker network configuration:${NC}"
echo -e "${YELLOW}docker network inspect ollama-webui-network${NC}"
echo ""
echo -e "${BLUE}3. Verify Open WebUI can reach Ollama:${NC}"
echo -e "${YELLOW}docker exec open-webui curl -s http://ollama:11434/api/tags${NC}"
echo ""
echo -e "${BLUE}4. Check logs for errors:${NC}"
echo -e "${YELLOW}cat /opt/ollama-webui/compose.log${NC}"
echo -e "${YELLOW}docker logs ollama${NC}"
echo -e "${YELLOW}docker logs open-webui${NC}"
echo ""
echo -e "${BLUE}5. Try running 'ollama list' to initialize models:${NC}"
echo -e "${YELLOW}docker exec ollama ollama list${NC}"
echo ""
echo -e "${BLUE}6. Check for port conflicts:${NC}"
echo -e "${YELLOW}sudo lsof -i :8080${NC}"
echo -e "${YELLOW}sudo lsof -i :11434${NC}"
echo ""
echo -e "${BLUE}7. Restart services if needed:${NC}"
echo -e "${YELLOW}cd /opt/ollama-webui && docker compose down && docker compose up -d && systemctl restart nginx${NC}"
echo "=========================================================="
