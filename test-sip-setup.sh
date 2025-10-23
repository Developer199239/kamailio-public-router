#!/bin/bash
# Kamailio and RTPEngine Test Script
# Run this on your server to test the setup

echo "=== Kamailio & RTPEngine Testing Script ==="
echo ""

# 1. Check services
echo "1. Checking service status..."
systemctl is-active kamailio && echo "✓ Kamailio is running" || echo "✗ Kamailio is NOT running"
systemctl is-active rtpengine && echo "✓ RTPEngine is running" || echo "✗ RTPEngine is NOT running"
echo ""

# 2. Check listening ports
echo "2. Checking listening ports..."
netstat -tulpn | grep -E ':5060|:5061|:2223' | head -10
echo ""

# 3. Test SIP OPTIONS (keepalive)
echo "3. Testing SIP OPTIONS to Kamailio..."
sipsak -vv -s sip:c5.sandboxegytelecoms.com:5060
echo ""

# 4. Check database connection
echo "4. Testing database connection..."
mysql -u kamailio -pkamailiorw kamailio -e "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema='kamailio';" 2>/dev/null && echo "✓ Database connected" || echo "✗ Database connection failed"
echo ""

# 5. Test RTPEngine control socket
echo "5. Testing RTPEngine control socket..."
echo "ping" | nc -u 127.0.0.1 2223 -w 1 && echo "✓ RTPEngine responding" || echo "✗ RTPEngine not responding"
echo ""

# 6. Check TLS certificates
echo "6. Checking TLS certificate..."
openssl s_client -connect c5.sandboxegytelecoms.com:5061 -servername c5.sandboxegytelecoms.com </dev/null 2>/dev/null | grep -E 'subject=|issuer=' | head -5
echo ""

# 7. View recent Kamailio logs
echo "7. Recent Kamailio logs (last 10 lines)..."
journalctl -u kamailio -n 10 --no-pager
echo ""

# 8. Check registered users
echo "8. Checking registered users..."
kamctl ul show 2>/dev/null | grep -E 'AOR:|Contact:' | head -20
echo ""

echo "=== Test Complete ==="
