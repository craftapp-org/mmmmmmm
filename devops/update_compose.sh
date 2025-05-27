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

# Function to clean and update networks section
update_networks() {
  awk -v network="$network_name" '
  BEGIN {
    in_nginx = 0
    in_networks = 0
    networks_found = 0
    added_new = 0
  }
  /^  nginx:/ { in_nginx = 1 }
  in_nginx && /^    networks:/ { 
    in_networks = 1
    networks_found = 1
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

# Function to update network definitions
update_network_definitions() {
  awk -v network="$network_name" '
  BEGIN {
    in_networks = 0
    added_new = 0
  }
  /^networks:/ { 
    in_networks = 1
    print
    next
  }
  in_networks && /^  [a-zA-Z0-9_-]+_app-network:/ {
    if (!seen_definitions[$0]++) {
      print
      getline
      if (/^    external: true/) print
    }
    next
  }
  in_networks && !/^  [a-zA-Z0-9_-]+_app-network:/ {
    if (!added_new && !seen_definitions["  " network ":"]) {
      print "  " network ":"
      print "    external: true"
      added_new = 1
    }
    in_networks = 0
    print
    next
  }
  { print }
  '
}

# Process the file in stages
update_networks > "$temp_file"
update_network_definitions < "$temp_file" > "$compose_file"

# Verify YAML syntax
cd "$compose_dir" || exit 1
if ! docker compose config -q; then
  echo "❌ Error: Invalid YAML after update. Restoring backup."
  mv "$backup_file" "$compose_file"
  exit 1
fi

# Restart the container
echo "🔄 Restarting central-nginx container..."
docker compose up -d --force-recreate nginx

# Clean up
rm -f "$temp_file"
echo "✅ Updated $compose_file with network $network_name"
