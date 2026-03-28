#!/bin/bash

# ==============================================================================
# ERPNext DigitalOcean Production Deployment Script
# Specifically designed for domain: erp.seinnyaungso.com
# 
# Prerequisites before running this script on your Droplet:
# 1. Droplet is created (Ubuntu 24.04, minimum 4GB RAM)
# 2. DNS A record for 'erp' points to this Droplet's IP
# ==============================================================================

set -e # Exit immediately if a command exits with a non-zero status

echo "🚀 Starting ERPNext Deployment preparation..."

# 1. Install Docker & Docker Compose (if not already installed)
if ! command -v docker &> /dev/null; then
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com | bash
fi

if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    echo "📦 Installing Docker Compose..."
    DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
    mkdir -p $DOCKER_CONFIG/cli-plugins
    curl -SL https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
    chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose
fi

# 2. Setup Directories
echo "📂 Setting up working directories..."
mkdir -p ~/gitops
cd ~/gitops

# 3. Clone Repository (if not already cloned)
if [ ! -d "frappe_docker" ]; then
    echo "📥 Cloning your frappe_docker repository..."
    git clone https://github.com/winmoee/frappe_docker.git
fi

cd frappe_docker

# 4. Generate Traefik configuration
echo "🌐 Generating Traefik Configuration..."
cat << EOF > ~/gitops/traefik.env
TRAEFIK_DOMAIN=erp.seinnyaungso.com
EMAIL=admin@seinnyaungso.com
# Default password is 'admin' (you can regenerate this via htpasswd later)
HASHED_PASSWORD=\$apr1\$K.4gp7RT\$tj9R2jHh0D4Gb5o5fIAzm/
EOF

# 5. Generate MariaDB configuration
echo "🗄️ Generating MariaDB Configuration..."
cat << EOF > ~/gitops/mariadb.env
DB_PASSWORD=SecureDbPassword123!
EOF

# 6. Generate ERPNext configuration
echo "⚙️ Generating ERPNext Configuration..."
cp example.env ~/gitops/erpnext.env
# Substitute necessary variables
sed -i 's/DB_PASSWORD=123/DB_PASSWORD=SecureDbPassword123!/g' ~/gitops/erpnext.env
sed -i 's/DB_HOST=/DB_HOST=mariadb-database/g' ~/gitops/erpnext.env
sed -i 's/DB_PORT=/DB_PORT=3306/g' ~/gitops/erpnext.env
sed -i 's/SITES_RULE=Host(\`erp.example.com\`)/SITES_RULE=Host(\`erp.seinnyaungso.com\`)/g' ~/gitops/erpnext.env
sed -i 's/LETSENCRYPT_EMAIL=mail@example.com/LETSENCRYPT_EMAIL=admin@seinnyaungso.com/g' ~/gitops/erpnext.env
sed -i 's/ERPNEXT_VERSION=v16.11.0/ERPNEXT_VERSION=latest/g' ~/gitops/erpnext.env
echo 'ROUTER=erpnext' >> ~/gitops/erpnext.env
echo "BENCH_NETWORK=erpnext" >> ~/gitops/erpnext.env

# 7. Generate Compose YAMLs
echo "🏗️ Building Docker Compose files..."

# Traefik compose
docker compose --project-name traefik \
  --env-file ~/gitops/traefik.env \
  -f overrides/compose.traefik.yaml \
  -f overrides/compose.traefik-ssl.yaml config > ~/gitops/traefik.yaml

# ERPNext compose
docker compose --project-name erpnext \
  --env-file ~/gitops/erpnext.env \
  -f compose.yaml \
  -f overrides/compose.maridb-shared.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.multi-bench.yaml \
  -f overrides/compose.multi-bench-ssl.yaml config > ~/gitops/erpnext.yaml

echo ""
echo "✅ Configuration Generated Successfully!"
echo "====================================================================="
echo "To finish deployment, run the following commands manually:"
echo ""
echo "1. Start Traefik (Load Balancer):"
echo "   docker compose --project-name traefik -f ~/gitops/traefik.yaml up -d"
echo ""
echo "2. Start ERPNext & Database:"
echo "   docker compose --project-name erpnext -f ~/gitops/erpnext.yaml up -d"
echo ""
echo "3. Create the Frappe Site (The Database):"
echo "   docker compose --project-name erpnext exec backend bench new-site --mariadb-user-host-login-scope=% --db-root-password SecureDbPassword123! --install-app erpnext --admin-password AdminPassword123! erp.seinnyaungso.com"
echo ""
echo "4. IMPORTANT: Run the Symlink Fix (As done locally):"
echo "   docker compose --project-name erpnext exec backend bash -c \"cd sites/assets && for dir in frappe erpnext; do if [ -L \\\$dir ]; then cp -rL \\\$dir \\\\\\\${dir}_copy && rm \\\$dir && mv \\\\\\\${dir}_copy \\\$dir; fi; done\""
echo "====================================================================="
