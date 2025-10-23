# Kamailio Networking Implementation Summary

## Overview
This document summarizes the networking logic implementation for the Kamailio public router with domain-based routing to multiple Asterisk servers across a VPN network.

## What Was Implemented

### 1. Network Configuration
- **VPN Network**: 10.10.50.0/23 (supports 512 hosts)
- **Server Subnet**: 10.10.40.0/24 (where Asterisk servers are located)
- **Kamailio VPN IP**: 10.10.40.127
- **Primary Asterisk**: 10.10.40.117 (ast1.sandboxegytelecoms.com)

### 2. Domain-Based Routing System
Implemented a flexible, expandable routing system using Kamailio's hash table module:

```kamailio
# Hash table for domain-to-IP mappings
modparam("htable", "htable", "asterisk_servers=>size=8;autoexpire=0;")

# Initialization route populates the mappings
event_route[htable:mod-init] {
    $sht(asterisk_servers=>ast1.sandboxegytelecoms.com) = "10.10.40.117";
    $sht(asterisk_servers=>ast1) = "10.10.40.117";
    # Easy to add more servers...
}
```

### 3. Intelligent Route Selection
Created `SELECT_ASTERISK` route that performs domain lookup in this order:
1. Request-URI domain (`$rd`)
2. Subdomain pattern matching (e.g., ast1, ast2)
3. From domain (`$fd`)
4. To domain (`$td`)
5. Falls back to default server if no match

### 4. VPN Traffic Detection
Implemented `CHECK_VPN_SOURCE` route to identify internal vs external traffic:
- Detects 10.10.50.0/23 (VPN network)
- Detects 10.10.40.0/24 (server subnet)
- Enables different handling for internal vs external sources

### 5. Enhanced Logging
Added comprehensive logging for:
- VPN vs public traffic identification
- Domain-to-IP mapping resolution
- Selected Asterisk server for each request
- Routing decisions and fallbacks

## Configuration Changes

### Files Modified
1. **kamailio.cfg**
   - Added VPN network definitions
   - Added htable module for domain mappings
   - Created server initialization route
   - Implemented SELECT_ASTERISK routing logic
   - Added VPN source detection
   - Enhanced TOASTERISK route with domain-based selection
   - Updated REGISTRAR route for domain-based forwarding

### Files Created
1. **NETWORKING.md** - Complete networking architecture documentation
2. **ARCHITECTURE.md** - Visual diagrams and flow charts
3. **server-mappings.conf** - Server mapping reference document
4. **manage-servers.sh** - Interactive management script
5. **IMPLEMENTATION.md** - This file

## How to Add New Asterisk Servers

### Quick Steps
1. Assign VPN IP to new Asterisk server (e.g., 10.10.40.118)
2. Choose domain (e.g., ast2.sandboxegytelecoms.com)
3. Edit kamailio.cfg, add to event_route[htable:mod-init]:
   ```kamailio
   $sht(asterisk_servers=>ast2.sandboxegytelecoms.com) = "10.10.40.118";
   $sht(asterisk_servers=>ast2) = "10.10.40.118";
   ```
4. Deploy configuration to server
5. Restart Kamailio: `systemctl restart kamailio`
6. Test connectivity using manage-servers.sh

### Example: Adding Server 2
```bash
# 1. On remote server, edit configuration
ssh root@c5.sandboxegytelecoms.com

# 2. Edit kamailio.cfg
vi /etc/kamailio/kamailio.cfg

# 3. Add these lines in event_route[htable:mod-init]:
    # Server 2 - Secondary
    $sht(asterisk_servers=>ast2.sandboxegytelecoms.com) = "10.10.40.118";
    $sht(asterisk_servers=>ast2) = "10.10.40.118";

# 4. Test configuration
kamailio -c -f /etc/kamailio/kamailio.cfg

# 5. Restart
systemctl restart kamailio

# 6. Verify
tail -f /var/log/syslog | grep kamailio
```

## Routing Examples

### Example 1: INVITE to Specific Server
```
INVITE sip:1000@ast1.sandboxegytelecoms.com SIP/2.0

Kamailio Processing:
1. Extract domain: ast1.sandboxegytelecoms.com
2. Lookup: $sht(asterisk_servers=>ast1.sandboxegytelecoms.com)
3. Result: 10.10.40.117
4. Set $du = "sip:10.10.40.117:5060"
5. Forward to Asterisk 1
```

### Example 2: REGISTER with Short Name
```
REGISTER sip:ast2 SIP/2.0

Kamailio Processing:
1. Extract domain: ast2
2. Lookup: $sht(asterisk_servers=>ast2)
3. Result: 10.10.40.118
4. Set $du = "sip:10.10.40.118:5060"
5. Forward REGISTER to Asterisk 2
```

### Example 3: No Mapping Found
```
INVITE sip:9999@unknown.com SIP/2.0

Kamailio Processing:
1. Extract domain: unknown.com
2. Lookup: $sht(asterisk_servers=>unknown.com)
3. Result: NULL (not found)
4. Use default: ASTERISK_IP = 10.10.40.117
5. Set $du = "sip:10.10.40.117:5060"
6. Forward to primary Asterisk
```

## Testing and Verification

### Test 1: Verify Hash Table Loading
```bash
# After Kamailio starts, check logs
grep "Asterisk server mappings initialized" /var/log/syslog
```

### Test 2: Test Server Connectivity
```bash
# Use management script
./manage-servers.sh

# Or manually
ping 10.10.40.117
nc -zv 10.10.40.117 5060
```

### Test 3: Test Domain Routing
```bash
# Send test INVITE
sipexten call sip:test@ast1.sandboxegytelecoms.com

# Monitor logs
tail -f /var/log/syslog | grep "Selected Asterisk server"
```

### Test 4: Verify VPN Detection
```bash
# Check logs for VPN traffic identification
tail -f /var/log/syslog | grep "VPN traffic"
tail -f /var/log/syslog | grep "Public traffic"
```

## Performance Considerations

### Hash Table Performance
- O(1) lookup time for domain-to-IP mapping
- Size=8 (supports up to 256 entries efficiently)
- No expiration (autoexpire=0) for permanent mappings

### Scalability
- Current design supports hundreds of Asterisk servers
- Each server requires only 2 hash table entries (domain + short name)
- No database queries required for routing decisions

### Memory Usage
- Hash table: ~4KB for typical configuration
- Minimal memory overhead per request
- No persistent storage required

## Security Features

### Loop Prevention
```kamailio
if ($(hdr(Via)[1]) =~ "c5.sandboxegytelecoms.com") {
    sl_send_reply("482","Loop Detected");
    exit;
}
```

### VPN Isolation
- Asterisk servers not directly accessible from internet
- All traffic routes through Kamailio
- VPN provides encrypted transport

### NAT Handling
- Automatic NAT detection
- RTPEngine for media relay
- Contact alias for NAT clients

## Monitoring and Maintenance

### Key Log Messages
```
"Asterisk server mappings initialized" - Startup successful
"Found mapping: domain -> IP" - Successful routing
"Using default Asterisk server" - Fallback to primary
"VPN traffic: $rm from $si" - Internal traffic detected
"Public traffic: $rm from $si" - External traffic detected
```

### Regular Maintenance
1. **Weekly**: Review logs for routing issues
2. **Monthly**: Verify all server mappings are current
3. **Quarterly**: Update documentation with new servers
4. **As needed**: Test connectivity to all Asterisk servers

## Troubleshooting Guide

### Issue: Calls not routing to specific server
**Check:**
1. Hash table entry exists: `grep "asterisk_servers=>domain" kamailio.cfg`
2. Server is reachable: `ping <IP>` and `nc -zv <IP> 5060`
3. Kamailio logs show correct mapping: `grep "Selected Asterisk" /var/log/syslog`

### Issue: Server mapping not found
**Solution:**
1. Verify entry in event_route[htable:mod-init]
2. Check for typos in domain name
3. Restart Kamailio to reload mappings
4. Verify with: `tail -f /var/log/syslog | grep "Found mapping"`

### Issue: VPN connectivity problems
**Check:**
1. VPN tunnel is up
2. Routing table includes VPN routes
3. Firewall allows traffic between Kamailio and Asterisk
4. Test with: `traceroute <asterisk-ip>`

## Future Enhancements

### Potential Improvements
1. **Load Balancing**: Distribute calls across multiple servers
2. **Health Checking**: Monitor Asterisk server availability
3. **Failover**: Automatic routing to backup servers
4. **Geographic Routing**: Route based on caller location
5. **Database Integration**: Store mappings in database for dynamic updates
6. **Web Interface**: GUI for managing server mappings

### Load Balancing Example (Future)
```kamailio
# Use dispatcher module for load balancing
loadmodule "dispatcher.so"

modparam("dispatcher", "list_file", "/etc/kamailio/dispatcher.list")
modparam("dispatcher", "flags", 2)

route[LOADBALANCE] {
    if(!ds_select_dst("1", "4")) {
        # No available servers
        sl_send_reply("503", "Service Unavailable");
        exit;
    }
}
```

## References

### Documentation Files
- **README.md** - Quick start and general information
- **NETWORKING.md** - Detailed networking documentation
- **ARCHITECTURE.md** - Visual diagrams and architecture
- **server-mappings.conf** - Server reference list

### Key Configuration Sections
- Lines 1-60: Global parameters and definitions
- Lines 61-90: Module loading
- Lines 91-180: Module parameters
- Lines 181-220: Server mapping initialization
- Lines 320-380: SELECT_ASTERISK routing logic
- Lines 290-320: TOASTERISK route with domain routing

## Deployment Checklist

- [x] VPN network configured (10.10.50.0/23)
- [x] Kamailio VPN IP assigned (10.10.40.127)
- [x] Primary Asterisk server configured (10.10.40.117)
- [x] Hash table module loaded and configured
- [x] Domain mappings initialized
- [x] SELECT_ASTERISK route implemented
- [x] VPN source detection implemented
- [x] Enhanced logging added
- [x] Documentation created
- [x] Management script created
- [ ] DNS records updated for subdomains
- [ ] Secondary Asterisk server deployed (10.10.40.118)
- [ ] Tertiary Asterisk server deployed (10.10.40.119)
- [ ] Load testing completed
- [ ] Monitoring configured

## Support and Contact

For issues or questions:
1. Check logs: `tail -f /var/log/syslog | grep kamailio`
2. Use management script: `./manage-servers.sh`
3. Review documentation: NETWORKING.md and ARCHITECTURE.md
4. Contact Egytel infrastructure team

---
*Implementation Date: October 23, 2025*
*Implemented by: GitHub Copilot for Egytel Telecommunications*
