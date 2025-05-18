#!/bin/bash

# Ensure interactive shell input only when script is not piped
get_domain() {
  if [ -n "$TIPI_DOMAIN" ]; then
    DOMAIN="$TIPI_DOMAIN"
  elif [ -t 0 ]; then
    # Only prompt if input is from terminal (interactive)
    read -p "Enter your domain name (e.g., mydomain.com): " DOMAIN
    if [ -z "$DOMAIN" ]; then
      echo "Error: Domain cannot be empty."
      exit 1
    fi
  else
    echo "Error: TIPI_DOMAIN env variable not set and no interactive shell to prompt for domain."
    exit 1
  fi
}

# Step 1: Install Tipi
echo "Installing Tipi..."
curl -L https://setup.runtipi.io | bash

# Step 2: Get domain
get_domain

# Step 3: Create settings.json
export CONFIG_DIR="$HOME/runtipi/state"
mkdir -p "$CONFIG_DIR"

cat <<EOF > "$CONFIG_DIR/settings.json"
{
  "domain": "$DOMAIN"
}
EOF

echo "settings.json created at $CONFIG_DIR with domain: $DOMAIN"

# Step 4: Restart Tipi
echo "Restarting Tipi..."
cd "$CONFIG_DIR"
sudo ./runtipi-cli restart

echo "✅ Tipi setup complete."
