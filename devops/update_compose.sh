#!/bin/bash

# Argument: project name
project_name="$1"

# Sanitize project name
sanitize_name() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//'
}
network_name="$(sanitize_name "$project_name")_app-network"

# Path configuration
compose_dir="$HOME/app/central-nginx"
compose_file="$compose_dir/docker-compose.yml"
temp_file=$(mktemp)
backup_file="${compose_file}.bak"

# Verify compose file exists
if [ ! -f "$compose_file" ]; then
  echo "❌ Error: docker-compose.yml not found at $compose_file"
  exit 1
fi

# Create backup
cp "$compose_file" "$backup_file"

# First ensure all referenced networks are properly defined
ensure_network_definitions() {
  # Get all networks referenced in the file
  referenced_networks=$(grep -oP '^\s+-\s+\K[a-zA-Z0-9_-]+_app-network' "$compose_file" | sort -u)
  
  # Add any missing network definitions
  for net in $referenced_networks; do
    if ! grep -q "^  $net:" "$compose_file"; then
      echo "  $net:" >> "$compose_file"
      echo "    external: true" >> "$compose_file"
    fi
  done
}

# Update networks section under nginx service
update_networks() {
  awk -v network="$network_name" '
  BEGIN {
    in_nginx = 0
    in_networks = 0
    added_new = 0
  }
  /^  nginx:/ { in_nginx = 1 }
  in_nginx && /^    networks:/ { 
    in_networks = 1
    print
    next
  }
  in_networks && /^      - / {
    if (!seen_networks[$0]++) {
      print
    }
    next
  }
  in_networks && !/^      - / {
    if (!added_new && !seen_networks["      - " network]) {
      print "      - " network
      added_new = 1
    }
    in_networks = 0
    print
    next
  }
  /^  [a-zA-Z]/ && !/^  nginx:/ { in_nginx = 0 }
  { print }
  ' "$compose_file"
}

# Process the file
ensure_network_definitions
update_networks > "$temp_file"
mv "$temp_file" "$compose_file"

# Ensure our new network is defined
if ! grep -q "^  $network_name:" "$compose_file"; then
  echo "  $network_name:" >> "$compose_file"
  echo "    external: true" >> "$compose_file"
fi

# Validate the compose file
cd "$compose_dir" || exit 1
if ! docker compose config -q; then
  echo "❌ Error: Invalid Docker Compose configuration. Restoring backup."
  mv "$backup_file" "$compose_file"
  exit 1
fi

# Restart the container
echo "🔄 Restarting central-nginx container..."
docker compose up -d --force-recreate nginx

# Clean up
rm -f "$temp_file"
echo "✅ Successfully updated $compose_file with network $network_name"
