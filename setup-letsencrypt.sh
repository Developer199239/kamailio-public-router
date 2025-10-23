#!/bin/bash
# Let's Encrypt Certificate Generation Script for Kamailio
# Generates wildcard certificate for *.dc05.sandboxegytelecoms.com

set -e

DOMAIN="dc05.sandboxegytelecoms.com"
WILDCARD_DOMAIN="*.dc05.sandboxegytelecoms.com"
EMAIL="admin@egytelecoms.com"  # Change this to your email
CERT_PATH="/etc/letsencrypt/live/${DOMAIN}"
KAMAILIO_CERT_DIR="/etc/kamailio/certs"

echo "=========================================="
echo "Let's Encrypt Certificate Setup"
echo "Domain: ${WILDCARD_DOMAIN}"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "Error: Please run as root"
    exit 1
fi

# Create Kamailio certificate directory
mkdir -p ${KAMAILIO_CERT_DIR}

echo ""
echo "Certificate generation options:"
echo "1. Manual DNS challenge (recommended for first time)"
echo "2. Cloudflare DNS (requires API token)"
echo "3. Use existing certificate (if already generated)"
echo ""
read -p "Select option [1-3]: " option

case $option in
    1)
        echo ""
        echo "=== Manual DNS Challenge ==="
        echo "You will need to add TXT records to your DNS."
        echo ""
        
        certbot certonly \
            --manual \
            --preferred-challenges dns \
            --email ${EMAIL} \
            --agree-tos \
            --no-eff-email \
            -d ${DOMAIN} \
            -d ${WILDCARD_DOMAIN}
        ;;
    
    2)
        echo ""
        echo "=== Cloudflare DNS Challenge ==="
        
        # Check for Cloudflare credentials
        CF_CRED_FILE="/root/.secrets/cloudflare.ini"
        
        if [ ! -f "${CF_CRED_FILE}" ]; then
            echo "Creating Cloudflare credentials file..."
            mkdir -p /root/.secrets
            
            read -p "Enter your Cloudflare API Token: " cf_token
            
            cat > ${CF_CRED_FILE} << EOF
# Cloudflare API token
dns_cloudflare_api_token = ${cf_token}
EOF
            chmod 600 ${CF_CRED_FILE}
            echo "Credentials saved to ${CF_CRED_FILE}"
        fi
        
        echo "Generating certificate using Cloudflare DNS..."
        certbot certonly \
            --dns-cloudflare \
            --dns-cloudflare-credentials ${CF_CRED_FILE} \
            --email ${EMAIL} \
            --agree-tos \
            --no-eff-email \
            -d ${DOMAIN} \
            -d ${WILDCARD_DOMAIN}
        ;;
    
    3)
        echo "Using existing certificate..."
        ;;
    
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

# Check if certificate was generated
if [ ! -d "${CERT_PATH}" ]; then
    echo ""
    echo "Error: Certificate directory not found at ${CERT_PATH}"
    echo "Certificate generation may have failed."
    exit 1
fi

echo ""
echo "=== Certificate Generated Successfully ==="
ls -la ${CERT_PATH}/

# Create combined certificate file for Kamailio
echo ""
echo "Creating combined certificate file for Kamailio..."

cat ${CERT_PATH}/fullchain.pem ${CERT_PATH}/privkey.pem > ${KAMAILIO_CERT_DIR}/kamailio-cert.pem

# Set proper permissions
chmod 640 ${KAMAILIO_CERT_DIR}/kamailio-cert.pem
chown root:kamailio ${KAMAILIO_CERT_DIR}/kamailio-cert.pem 2>/dev/null || chown root:root ${KAMAILIO_CERT_DIR}/kamailio-cert.pem

# Copy individual files as well
cp ${CERT_PATH}/cert.pem ${KAMAILIO_CERT_DIR}/cert.pem
cp ${CERT_PATH}/privkey.pem ${KAMAILIO_CERT_DIR}/privkey.pem
cp ${CERT_PATH}/chain.pem ${KAMAILIO_CERT_DIR}/chain.pem
cp ${CERT_PATH}/fullchain.pem ${KAMAILIO_CERT_DIR}/fullchain.pem

chmod 640 ${KAMAILIO_CERT_DIR}/*.pem
chown root:kamailio ${KAMAILIO_CERT_DIR}/*.pem 2>/dev/null || chown root:root ${KAMAILIO_CERT_DIR}/*.pem

echo "Certificate files created in ${KAMAILIO_CERT_DIR}/"
ls -la ${KAMAILIO_CERT_DIR}/

# Update TLS configuration
echo ""
echo "=== Updating Kamailio TLS Configuration ==="

TLS_CFG="/etc/kamailio/tls.cfg"

if [ -f "${TLS_CFG}" ]; then
    # Backup existing configuration
    cp ${TLS_CFG} ${TLS_CFG}.backup.$(date +%Y%m%d_%H%M%S)
    echo "Backup created: ${TLS_CFG}.backup.*"
fi

cat > ${TLS_CFG} << 'EOF'
[server:default]
method = TLSv1.2+
verify_certificate = no
require_certificate = no
private_key = /etc/kamailio/certs/privkey.pem
certificate = /etc/kamailio/certs/fullchain.pem
ca_list = /etc/kamailio/certs/chain.pem
crl = 
cipher_list = HIGH:!aNULL:!MD5:!RC4

[client:default]
method = TLSv1.2+
verify_certificate = no
require_certificate = no
private_key = /etc/kamailio/certs/privkey.pem
certificate = /etc/kamailio/certs/fullchain.pem
ca_list = /etc/kamailio/certs/chain.pem
crl = 
cipher_list = HIGH:!aNULL:!MD5:!RC4
EOF

echo "TLS configuration updated: ${TLS_CFG}"

# Set up auto-renewal hook
echo ""
echo "=== Setting Up Auto-Renewal Hook ==="

RENEWAL_HOOK="/etc/letsencrypt/renewal-hooks/post/kamailio-reload.sh"
mkdir -p /etc/letsencrypt/renewal-hooks/post

cat > ${RENEWAL_HOOK} << 'EOFHOOK'
#!/bin/bash
# Post-renewal hook to update Kamailio certificates

CERT_PATH="/etc/letsencrypt/live/dc05.sandboxegytelecoms.com"
KAMAILIO_CERT_DIR="/etc/kamailio/certs"

# Create combined certificate
cat ${CERT_PATH}/fullchain.pem ${CERT_PATH}/privkey.pem > ${KAMAILIO_CERT_DIR}/kamailio-cert.pem

# Copy individual files
cp ${CERT_PATH}/cert.pem ${KAMAILIO_CERT_DIR}/cert.pem
cp ${CERT_PATH}/privkey.pem ${KAMAILIO_CERT_DIR}/privkey.pem
cp ${CERT_PATH}/chain.pem ${KAMAILIO_CERT_DIR}/chain.pem
cp ${CERT_PATH}/fullchain.pem ${KAMAILIO_CERT_DIR}/fullchain.pem

# Set permissions
chmod 640 ${KAMAILIO_CERT_DIR}/*.pem
chown root:kamailio ${KAMAILIO_CERT_DIR}/*.pem 2>/dev/null || chown root:root ${KAMAILIO_CERT_DIR}/*.pem

# Reload Kamailio
systemctl reload kamailio || systemctl restart kamailio

echo "Kamailio certificates updated and service reloaded: $(date)"
EOFHOOK

chmod +x ${RENEWAL_HOOK}
echo "Auto-renewal hook created: ${RENEWAL_HOOK}"

# Test auto-renewal
echo ""
echo "=== Testing Certificate Auto-Renewal ==="
certbot renew --dry-run

echo ""
echo "=========================================="
echo "Certificate Setup Complete!"
echo "=========================================="
echo ""
echo "Certificate Information:"
echo "  Domain: ${DOMAIN}, ${WILDCARD_DOMAIN}"
echo "  Certificate Path: ${CERT_PATH}/"
echo "  Kamailio Cert Dir: ${KAMAILIO_CERT_DIR}/"
echo ""
echo "Next Steps:"
echo "  1. Update kamailio.cfg with new domain alias"
echo "  2. Ensure TLS listening on port 5061"
echo "  3. Restart Kamailio: systemctl restart kamailio"
echo "  4. Test TLS connection: openssl s_client -connect dc05.sandboxegytelecoms.com:5061"
echo ""
echo "Certificate will auto-renew every 60 days."
echo "=========================================="
