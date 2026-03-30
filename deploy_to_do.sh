#!/bin/bash

# ==============================================================================
# ERPNext DigitalOcean Production Deployment Script
# Specifically designed for domain: sys.joinworkify.com
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

# 4. Create internal networks
echo "🌐 Creating Docker networks..."
docker network create traefik-public || true
docker network create mariadb-network || true

# 5. Generate Traefik configuration
echo "🌐 Generating Traefik Configuration..."
cat << EOF > ~/gitops/traefik.env
TRAEFIK_DOMAIN=sys.joinworkify.com
EMAIL=admin@joinworkify.com
# Note: Dollar signs are doubled ($$) for docker-compose interpolation
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

# Use simple search and replace for common variables
sed -i 's|DB_PASSWORD=123|DB_PASSWORD=SecureDbPassword123!|g' ~/gitops/erpnext.env
sed -i 's|DB_HOST=|DB_HOST=mariadb-database|g' ~/gitops/erpnext.env
sed -i 's|DB_PORT=|DB_PORT=3306|g' ~/gitops/erpnext.env
sed -i 's|ERPNEXT_VERSION=v16.11.0|ERPNEXT_VERSION=latest|g' ~/gitops/erpnext.env

# FORCE OVERWRITE the SITES_RULE line (using double backslash for backtick in bash)
sed -i 's|^SITES_RULE=.*|SITES_RULE=Host(`sys.joinworkify.com`)|g' ~/gitops/erpnext.env
sed -i 's|^LETSENCRYPT_EMAIL=.*|LETSENCRYPT_EMAIL=admin@joinworkify.com|g' ~/gitops/erpnext.env

echo 'ROUTER=erpnext' >> ~/gitops/erpnext.env
echo "BENCH_NETWORK=erpnext" >> ~/gitops/erpnext.env

# 8. Generate Separate Compose YAMLs
echo "🏗️ Building Docker Compose files..."

docker compose --project-name traefik --env-file ~/gitops/traefik.env -f overrides/compose.traefik.yaml -f overrides/compose.traefik-ssl.yaml config > ~/gitops/traefik.yaml
docker compose --project-name mariadb --env-file ~/gitops/mariadb.env -f overrides/compose.mariadb-shared.yaml config > ~/gitops/mariadb.yaml
docker compose --project-name erpnext --env-file ~/gitops/erpnext.env -f compose.yaml -f overrides/compose.redis.yaml -f overrides/compose.multi-bench.yaml -f overrides/compose.multi-bench-ssl.yaml config > ~/gitops/erpnext.yaml

echo ""
echo "✅ Configuration Generated Successfully!"
echo "====================================================================="
echo "To finish deployment, run these 3 commands on your VPS:"
echo ""
echo "1. Start ALL Services:"
echo "   docker compose -f ~/gitops/traefik.yaml up -d && docker compose -f ~/gitops/mariadb.yaml up -d && docker compose -f ~/gitops/erpnext.yaml up -d"
echo ""
echo "2. Create the Site (Wait ~2 mins):"
echo "   docker compose -f ~/gitops/erpnext.yaml exec backend bench new-site --mariadb-user-host-login-scope=% --db-root-password SecureDbPassword123! --install-app erpnext --admin-password AdminPassword123! sys.joinworkify.com"
echo ""
echo "3. Fix Styles (Symlink fix):"
echo "   docker compose -f ~/gitops/erpnext.yaml exec backend bash -c \"cd sites/assets && for dir in frappe erpnext; do if [ -L \\\$dir ]; then cp -rL \\\$dir \\\\\\\${dir}_copy && rm \\\$dir && mv \\\\\\\${dir}_copy \\\$dir; fi; done\""
echo "====================================================================="
