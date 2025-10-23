# Let's Encrypt Certificate Setup for Kamailio - DNS Challenge Guide

## Prerequisites
- Domain: `dc05.sandboxegytelecoms.com` and `*.dc05.sandboxegytelecoms.com`
- DNS access to create TXT records
- Root access to c5.sandboxegytelecoms.com

## Option 1: Manual DNS Challenge (Current Status)

### DNS Records Required
You need to add **TWO** TXT records to your DNS:

```
Name: _acme-challenge.dc05.sandboxegytelecoms.com
Type: TXT
Value: cj_ZjmldDmP78YVz678PIPM3vTr-1kUznu_z9r4CyEA

Name: _acme-challenge.dc05.sandboxegytelecoms.com
Type: TXT
Value: vNsr_JZV_QibIrOucewQI90O5MjAP6hpM5zuIoMDtoQ
```

### Steps to Complete:
1. Log into your DNS provider (Cloudflare, Route53, etc.)
2. Navigate to DNS settings for sandboxegytelecoms.com
3. Add both TXT records above
4. Wait 2-5 minutes for DNS propagation
5. Verify with: `dig TXT _acme-challenge.dc05.sandboxegytelecoms.com`
6. Re-run the script on the server

## Option 2: Cloudflare API (Automated - Recommended)

If your domain uses Cloudflare DNS, you can automate this:

### 1. Get Cloudflare API Token
- Go to https://dash.cloudflare.com/profile/api-tokens
- Click "Create Token"
- Use template "Edit zone DNS"
- Select your domain (sandboxegytelecoms.com)
- Create token and copy it

### 2. Run on Remote Server
```bash
ssh root@c5.sandboxegytelecoms.com
cd /root
./setup-letsencrypt.sh
# Select option 2 (Cloudflare DNS)
# Paste your API token when prompted
```

## Option 3: Alternative DNS Providers

### For AWS Route53:
```bash
ssh root@c5.sandboxegytelecoms.com
apt-get install python3-certbot-dns-route53
certbot certonly --dns-route53 \
  -d dc05.sandboxegytelecoms.com \
  -d *.dc05.sandboxegytelecoms.com
```

### For Google Cloud DNS:
```bash
ssh root@c5.sandboxegytelecoms.com
apt-get install python3-certbot-dns-google
certbot certonly --dns-google \
  -d dc05.sandboxegytelecoms.com \
  -d *.dc05.sandboxegytelecoms.com
```

## Manual Certificate Generation (Alternative)

If you prefer to run commands manually:

```bash
# On c5.sandboxegytelecoms.com as root

# Create credentials file for Cloudflare (if using Cloudflare)
mkdir -p /root/.secrets
cat > /root/.secrets/cloudflare.ini << EOF
dns_cloudflare_api_token = YOUR_API_TOKEN_HERE
EOF
chmod 600 /root/.secrets/cloudflare.ini

# Generate certificate
certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials /root/.secrets/cloudflare.ini \
  --email admin@egytelecoms.com \
  --agree-tos \
  --no-eff-email \
  -d dc05.sandboxegytelecoms.com \
  -d *.dc05.sandboxegytelecoms.com

# Create Kamailio certificate directory
mkdir -p /etc/kamailio/certs

# Combine certificates for Kamailio
cat /etc/letsencrypt/live/dc05.sandboxegytelecoms.com/fullchain.pem \
    /etc/letsencrypt/live/dc05.sandboxegytelecoms.com/privkey.pem \
    > /etc/kamailio/certs/kamailio-cert.pem

# Copy individual files
cp /etc/letsencrypt/live/dc05.sandboxegytelecoms.com/*.pem /etc/kamailio/certs/

# Set permissions
chmod 640 /etc/kamailio/certs/*.pem
chown root:kamailio /etc/kamailio/certs/*.pem

# Restart Kamailio
systemctl restart kamailio
```

## Verify DNS TXT Records

Before proceeding, verify the TXT records are propagated:

```bash
# Check DNS TXT records
dig TXT _acme-challenge.dc05.sandboxegytelecoms.com +short

# Or use online tool
# https://toolbox.googleapps.com/apps/dig/#TXT/_acme-challenge.dc05.sandboxegytelecoms.com

# Or use nslookup
nslookup -type=TXT _acme-challenge.dc05.sandboxegytelecoms.com
```

You should see both challenge values returned.

## Troubleshooting

### Certificate Generation Fails
- Verify DNS records are properly configured
- Wait longer for DNS propagation (up to 10 minutes)
- Check firewall allows port 443 (if using HTTP challenge)
- Verify email address is valid

### Permission Issues
```bash
# Fix certificate permissions
chown -R root:kamailio /etc/kamailio/certs
chmod 750 /etc/kamailio/certs
chmod 640 /etc/kamailio/certs/*.pem
```

### Kamailio Won't Start with TLS
```bash
# Check TLS configuration
kamailio -c -f /etc/kamailio/kamailio.cfg

# View detailed logs
journalctl -u kamailio -n 100

# Test certificate
openssl x509 -in /etc/kamailio/certs/fullchain.pem -text -noout
```

## Next Steps After Certificate Generation

1. Update kamailio.cfg with dc05 domain
2. Update tls.cfg with certificate paths
3. Restart Kamailio
4. Test TLS connection
5. Configure auto-renewal

See LETSENCRYPT_INTEGRATION.md for complete integration guide.

---
*Created: October 23, 2025*
