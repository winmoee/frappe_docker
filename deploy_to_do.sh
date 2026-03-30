#!/bin/bash

# ==============================================================================
# ERPNext DigitalOcean Production Deployment Script
# Specifically designed for domain: erp.seinnyaungso.com
# ==============================================================================

set -e

echo "🚀 Starting ERPNext Deployment preparation..."

# 1. Install Docker & Docker Compose (if not already installed)
if ! command -v docker &> /dev/null; then
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com | bash
fi

# 2. Setup Directories
echo "📂 Setting up working directories..."
mkdir -p ~/gitops
cd ~/gitops

# 3. Clone or Update Repository
if [ ! -d "frappe_docker" ]; then
    echo "📥 Cloning your frappe_docker repository..."
    git clone https://github.com/winmoee/frappe_docker.git
else
    echo "♻️ Updating existing frappe_docker repository..."
    cd frappe_docker && git pull && cd ..
fi

cd frappe_docker

# 4. Create required external networks BEFORE building configs
echo "🌐 Creating Docker networks..."
docker network create traefik-public || true
docker network create mariadb-network || true

# 5. Generate Traefik configuration
echo "🌐 Generating Traefik Configuration..."
cat << EOF > ~/gitops/traefik.env
TRAEFIK_DOMAIN=erp.seinnyaungso.com
EMAIL=admin@seinnyaungso.com
# NOTE: Dollar signs are doubled ($$) for docker-compose interpolation
HASHED_PASSWORD=\$\$apr1\$\$K.4gp7RT\$\$tj9R2jHh0D4Gb5o5fIAzm/
EOF

# 6. Generate MariaDB configuration
echo "🗄️ Generating MariaDB Configuration..."
cat << EOF > ~/gitops/mariadb.env
DB_PASSWORD=SecureDbPassword123!
EOF

# 7. Generate ERPNext configuration
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

# 8. Generate Separate Compose YAMLs to avoid network conflicts
echo "🏗️ Building Docker Compose files..."

# Project 1: Traefik
docker compose --project-name traefik \
  --env-file ~/gitops/traefik.env \
  -f overrides/compose.traefik.yaml \
  -f overrides/compose.traefik-ssl.yaml config > ~/gitops/traefik.yaml

# Project 2: MariaDB (External to ERPNext)
docker compose --project-name mariadb \
  --env-file ~/gitops/mariadb.env \
  -f overrides/compose.mariadb-shared.yaml config > ~/gitops/mariadb.yaml

# Project 3: ERPNext
docker compose --project-name erpnext \
  --env-file ~/gitops/erpnext.env \
  -f compose.yaml \
  -f overrides/compose.redis.yaml \
  -f overrides/compose.multi-bench.yaml \
  -f overrides/compose.multi-bench-ssl.yaml config > ~/gitops/erpnext.yaml

echo ""
echo "✅ Configuration Generated Successfully!"
echo "====================================================================="
echo "To finish deployment, run these 5 commands on your VPS:"
echo ""
echo "1. Start Traefik (SSL Load Balancer):"
echo "   docker compose -f ~/gitops/traefik.yaml up -d"
echo ""
echo "2. Start MariaDB (Standalone Database):"
echo "   docker compose -f ~/gitops/mariadb.yaml up -d"
echo ""
echo "3. Start ERPNext:"
echo "   docker compose -f ~/gitops/erpnext.yaml up -d"
echo ""
echo "4. Create the Actual Site (This takes ~2 mins):"
echo "   docker compose -f ~/gitops/erpnext.yaml exec backend bench new-site --mariadb-user-host-login-scope=% --db-root-password SecureDbPassword123! --install-app erpnext --admin-password AdminPassword123! erp.seinnyaungso.com"
echo ""
echo "5. Fix Frontend Styles (Standard macOS/Symlink fix):"
echo "   docker compose -f ~/gitops/erpnext.yaml exec backend bash -c \"cd sites/assets && for dir in frappe erpnext; do if [ -L \\\$dir ]; then cp -rL \\\$dir \\\\\\\${dir}_copy && rm \\\$dir && mv \\\\\\\${dir}_copy \\\$dir; fi; done\""
echo "====================================================================="
