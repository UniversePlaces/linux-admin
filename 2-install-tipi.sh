#!/bin/bash

# Run Tipi install script
echo "Installing Tipi..."
curl -L https://setup.runtipi.io | bash

# Ask for domain input
read -p "Enter your domain name (e.g., mydomain.com): " DOMAIN

# Create config directory if not exists
CONFIG_DIR=~/runtipi
mkdir -p "$CONFIG_DIR"

# Write settings.json file
cat <<EOF > "$CONFIG_DIR/settings.json"
{
  "domain": "$DOMAIN"
}
EOF

echo "settings.json created with domain: $DOMAIN"

# Restart Tipi
echo "Restarting Tipi..."
tipi restart

echo "Setup complete."
