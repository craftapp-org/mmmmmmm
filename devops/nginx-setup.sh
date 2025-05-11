# #!/bin/bash

# # Arguments
# project_name="$1"   # e.g., "Shop App"
# email="$2"          # Email for Certbot SSL
# server_ip="$3"      # Your server IP (must be whitelisted in Namecheap)
# sld="$4"            # e.g., "yourdomain" (without TLD)
# tld="$5"            # e.g., "com"
# api_user="$6"       # Namecheap API username
# api_key="$7"        # Namecheap API key
# frontend_port="$8"  # Frontend port (e.g., 3000)
# backend_port="$9"   # Backend port (e.g., 8000)
# client_ip="$server_ip"

# # Sanitize project name to form subdomain
# sanitize_name() {
#   echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//'
# }
# host=$(sanitize_name "$project_name")
# domain="${host}.${sld}.${tld}"

# echo "➡ Creating subdomain: $domain"

# # Step 1: Get existing DNS records
# echo "🔍 Fetching current DNS records..."
# response=$(curl -s "https://api.namecheap.com/xml.response" \
#   -d "ApiUser=$api_user" \
#   -d "ApiKey=$api_key" \
#   -d "UserName=$api_user" \
#   -d "Command=namecheap.domains.dns.getHosts" \
#   -d "ClientIp=$client_ip" \
#   -d "SLD=$sld" \
#   -d "TLD=$tld")

# if [[ ! "$response" =~ "<ApiResponse" ]]; then
#   echo "❌ Failed to fetch DNS records from Namecheap."
#   exit 1
# fi

# # Step 2: Extract existing hosts
# echo "🛠 Updating DNS records with new subdomain..."
# hosts=()
# record_count=$(echo "$response" | grep -o "<host " | wc -l)

# for i in $(seq 1 "$record_count"); do
#   host_name=$(echo "$response" | grep -oP "<host .*?Name=\"\K[^\"]+" | sed -n "${i}p")
#   type=$(echo "$response" | grep -oP "<host .*?Type=\"\K[^\"]+" | sed -n "${i}p")
#   addr=$(echo "$response" | grep -oP "<host .*?Address=\"\K[^\"]+" | sed -n "${i}p")
#   ttl=$(echo "$response" | grep -oP "<host .*?TTL=\"\K[^\"]+" | sed -n "${i}p")

#   hosts+=("-d HostName${i}=$host_name -d RecordType${i}=$type -d Address${i}=$addr -d TTL${i}=$ttl")
# done

# # Step 3: Add new record for subdomain
# index=$((record_count + 1))
# hosts+=("-d HostName${index}=$host -d RecordType${index}=A -d Address${index}=$server_ip -d TTL${index}=60")

# # Step 4: Submit updated DNS records
# curl_args=(
#   -s "https://api.namecheap.com/xml.response"
#   -d "ApiUser=$api_user"
#   -d "ApiKey=$api_key"
#   -d "UserName=$api_user"
#   -d "Command=namecheap.domains.dns.setHosts"
#   -d "ClientIp=$client_ip"
#   -d "SLD=$sld"
#   -d "TLD=$tld"
# )

# for h in "${hosts[@]}"; do
#   curl_args+=($h)
# done

# update_response=$(curl "${curl_args[@]}")

# if [[ "$update_response" =~ "IsSuccess=\"true\"" ]]; then
#   echo "✅ Subdomain $domain added to Namecheap DNS."
# else
#   echo "❌ Failed to update DNS. Response:"
#   echo "$update_response"
#   exit 1
# fi

# # echo "⏳ Waiting 30 seconds for DNS to propagate..."
# # sleep 180

# # Step 5: Create NGINX config
# nginx_config="/etc/nginx/sites-available/$host"
# sudo tee "$nginx_config" > /dev/null <<EOF
# server {
#     listen 80;
#     server_name $domain;
#     return 301 https://\$host\$request_uri;
# }

# server {
#     listen 443 ssl http2;
#     server_name $domain;

#     ssl_certificate /etc/letsencrypt/live/craftapp.ai/fullchain.pem;
#     ssl_certificate_key /etc/letsencrypt/live/craftapp.ai/privkey.pem;
#     # ssl_certificate /etc/letsencrypt/live/${sld}.${tld}/fullchain.pem;
#     # ssl_certificate_key /etc/letsencrypt/live/${sld}.${tld}/privkey.pem;

#     ssl_protocols TLSv1.2 TLSv1.3;
#     ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
#     ssl_prefer_server_ciphers on;
#     ssl_session_cache shared:SSL:10m;
#     ssl_session_timeout 10m;

#     location / {
#         proxy_pass http://localhost:$frontend_port/;
#         proxy_http_version 1.1;
#         proxy_set_header Upgrade \$http_upgrade;
#         proxy_set_header Connection 'upgrade';
#         proxy_set_header Host \$host;
#         proxy_cache_bypass \$http_upgrade;
#     }

#     location /api/ {
#         proxy_pass http://localhost:$backend_port/;
#         proxy_http_version 1.1;
#         proxy_set_header Upgrade \$http_upgrade;
#         proxy_set_header Connection 'upgrade';
#         proxy_set_header Host \$host;
#         proxy_cache_bypass \$http_upgrade;
#     }
# }
# EOF

# sudo ln -sf "$nginx_config" "/etc/nginx/sites-enabled/$host"
# sudo nginx -t && sudo systemctl reload nginx
# if [ $? -ne 0 ]; then
#   echo "❌ NGINX configuration test failed. Aborting."
#   exit 1
# fi

# # Step 7: Issue SSL certificate
# echo "🔐 Issuing SSL certificate for $domain..."
# sudo certbot --nginx -d "$domain" --non-interactive --agree-tos -m "$email"

# echo "✅ Deployment complete: https://$domain"


#!/bin/bash

# Arguments
project_name="$1"   # e.g., "Shop App"
email="$2"          # Email for Certbot SSL
server_ip="$3"      # Your server IP (must already have DNS configured)
sld="$4"            # e.g., "yourdomain" (without TLD)
tld="$5"            # e.g., "com"
frontend_port="$6"  # Frontend port (e.g., 3000)
backend_port="$7"   # Backend port (e.g., 8000)

# Sanitize project name to form subdomain
sanitize_name() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/^-*//;s/-*$//'
}
host=$(sanitize_name "$project_name")
domain="${host}.${sld}.${tld}"

echo "➡ Configuring domain: $domain (assuming DNS is already set up)"

# Step 1: Create NGINX config
nginx_config="/etc/nginx/sites-available/$host"
sudo tee "$nginx_config" > /dev/null <<EOF
server {
    listen 80;
    server_name $domain;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $domain;

    ssl_certificate /etc/letsencrypt/live/${sld}.${tld}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${sld}.${tld}/privkey.pem;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    location / {
        proxy_pass http://localhost:$frontend_port/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    location /api/ {
        proxy_pass http://localhost:$backend_port/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Step 2: Enable the NGINX config
sudo ln -sf "$nginx_config" "/etc/nginx/sites-enabled/$host"
sudo nginx -t && sudo systemctl reload nginx
if [ $? -ne 0 ]; then
  echo "❌ NGINX configuration test failed. Aborting."
  exit 1
fi

# Step 3: Issue SSL certificate (if needed)
echo "🔐 Issuing SSL certificate for $domain..."
sudo certbot --nginx -d "$domain" --non-interactive --agree-tos -m "$email"

echo "✅ Deployment complete: https://$domain"