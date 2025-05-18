#!/bin/bash

# Function to ask for domain if not provided
get_domain() {
  if [ -n "$1" ]; then
    DOMAIN="$1"
  else
    read -p "Enter your domain name (e.g., mydomain.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then
      echo "Error: Domain cannot be empty."
      exit 1
    fi
  fi
}

# Step 1: Install Tipi
echo "Installing Tipi..."
curl -L https://setup.runtipi.io | bash

# Step 2: Get domain from argument or prompt
get_domain "$1"

# Step 3: Create settings.json
CONFIG_DIR="$HOME/runtipi"
mkdir -p "$CONFIG_DIR"

cat <<EOF > "$CONFIG_DIR/settings.json"
{
  "domain": "$DOMAIN"
}
EOF

echo "settings.json created at $CONFIG_DIR with domain: $DOMAIN"

# Step 4: Restart Tipi
cd "$CONFIG_DIR"
sudo ./runtipi-cli restart

echo "✅ Tipi setup complete."
