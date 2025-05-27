#!/bin/bash

# Argument: project name (same format as used in the NGINX script)
project_name="$1"

# Sanitize project name to match network naming convention
sanitize_name() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//'
}
network_name="$(sanitize_name "$project_name")_app-network"

# Path to docker-compose.yml
compose_dir="$HOME/app/central-nginx"
compose_file="$compose_dir/docker-compose.yml"

# Verify file exists
if [ ! -f "$compose_file" ]; then
  echo "❌ Error: docker-compose.yml not found at $compose_file"
  exit 1
fi

# Temporary files
temp_file1=$(mktemp)
temp_file2=$(mktemp)

# Change to compose directory to ensure relative paths work
cd "$compose_dir" || exit 1

# 1. Add to networks section in nginx service
awk -v network="$network_name" '
  /^    networks:/ { print; found=1; next }
  found && /^      - [a-zA-Z0-9_-]+_app-network/ { print }
  found && !/^      - [a-zA-Z0-9_-]+_app-network/ { 
    print "      - " network
    print $0
    found=0
    next
  }
  { print }
' "$compose_file" > "$temp_file1"

# 2. Add to networks definition at bottom
awk -v network="$network_name" '
  /^networks:/ { print; in_networks=1; next }
  in_networks && /^  [a-zA-Z0-9_-]+_app-network:/ { print }
  in_networks && !/^  [a-zA-Z0-9_-]+_app-network:/ && !/^  [a-zA-Z0-9_-]+_app-network:/ { 
    print "  " network ":"
    print "    external: true"
    print $0
    in_networks=0
    next
  }
  { print }
' "$temp_file1" > "$temp_file2"

# Replace original file if changes were made
if ! diff "$compose_file" "$temp_file2" >/dev/null; then
  sudo mv "$temp_file2" "$compose_file"
  echo "✅ Updated $compose_file with network $network_name"
  
  # Restart the nginx container to apply changes
  echo "🔄 Restarting central-nginx container..."
  sudo docker compose up -d --force-recreate nginx
else
  echo "ℹ️ Network $network_name already exists in $compose_file"
fi

# Clean up
rm -f "$temp_file1"
