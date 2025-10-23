# Kamailio Networking Configuration

## Network Topology

### VPN Network Configuration
- **VPN Network**: `10.10.50.0/23` (10.10.50.0 - 10.10.51.255)
- **Internal Network**: `10.10.40.0/24` (where servers are deployed)
- **Kamailio VPN IP**: `10.10.40.127`
- **Primary Asterisk Server**: `10.10.40.117`

### Public Interface
- **Public Domain**: `c5.sandboxegytelecoms.com`
- **Public IP**: `101.46.69.57`
- **Listening Ports**:
  - UDP: 5060
  - TCP: 5060
  - TLS: 5061

## Domain-Based Routing

### How It Works

Kamailio maintains a hash table mapping public domains/subdomains to internal VPN IP addresses. This allows for:

1. **Scalable Architecture**: Easy addition of new Asterisk servers
2. **Domain-Based Routing**: Route calls based on the domain in the SIP URI
3. **Centralized Management**: All server mappings in one place

### Server Mapping Table

The server mappings are defined in the `event_route[htable:mod-init]` section:

```kamailio
# Server 1 - Primary
$sht(asterisk_servers=>ast1.sandboxegytelecoms.com) = "10.10.40.117";
$sht(asterisk_servers=>ast1) = "10.10.40.117";

# Add more servers:
# $sht(asterisk_servers=>ast2.sandboxegytelecoms.com) = "10.10.40.118";
# $sht(asterisk_servers=>ast2) = "10.10.40.118";
```

### Routing Logic

The `SELECT_ASTERISK` route determines which Asterisk server to use:

1. **Request-URI Domain**: First checks the domain in the Request-URI (`$rd`)
2. **Subdomain Pattern**: Matches patterns like `ast1`, `ast2`, etc.
3. **From Domain**: Checks the From header domain (`$fd`)
4. **To Domain**: Checks the To header domain (`$td`)
5. **Default**: Falls back to primary server if no mapping found

## Adding New Asterisk Servers

### Step 1: Assign VPN IP
Ensure the new Asterisk server is connected to the VPN network and has an IP in the range:
- `10.10.40.0/24` (recommended)
- `10.10.50.0/23` (alternative)

### Step 2: Choose a Domain/Subdomain
Decide on a public domain or subdomain for the server:
- `ast2.sandboxegytelecoms.com`
- `ast3.sandboxegytelecoms.com`
- Or use custom domains

### Step 3: Update Kamailio Configuration

Edit `kamailio.cfg` and add the mapping in the `event_route[htable:mod-init]` section:

```kamailio
# Server 2 - Secondary
$sht(asterisk_servers=>ast2.sandboxegytelecoms.com) = "10.10.40.118";
$sht(asterisk_servers=>ast2) = "10.10.40.118";
```

### Step 4: Update DNS (if needed)
If using a new subdomain, add DNS A record:
```
ast2.sandboxegytelecoms.com.  IN  A  101.46.69.57
```

### Step 5: Restart Kamailio
```bash
systemctl restart kamailio
```

### Step 6: Test
Test the new server mapping:
```bash
# Register to the new server
sipexten register sip:user@ast2.sandboxegytelecoms.com

# Make a test call
sipexten call sip:destination@ast2.sandboxegytelecoms.com
```

## Current Server Configuration

| Domain/Subdomain | VPN IP | Status | Purpose |
|------------------|---------|--------|---------|
| `ast1.sandboxegytelecoms.com` | 10.10.40.117 | Active | Primary Server |
| `ast2.sandboxegytelecoms.com` | 10.10.40.118 | Planned | Secondary Server |
| `ast3.sandboxegytelecoms.com` | 10.10.40.119 | Planned | Tertiary Server |

## Traffic Flow

### Inbound Call (Public → VPN)
1. External SIP client sends INVITE to `sip:user@ast1.sandboxegytelecoms.com:5060`
2. Kamailio receives on public interface (101.46.69.57:5060)
3. NAT detection and RTPEngine engagement
4. Domain lookup: `ast1.sandboxegytelecoms.com` → `10.10.40.117`
5. Forward to Asterisk via VPN: `sip:10.10.40.117:5060`
6. Asterisk processes the call

### Outbound Call (VPN → Public)
1. Asterisk sends INVITE from VPN (10.10.40.117)
2. Kamailio receives on VPN interface
3. Identifies as VPN traffic
4. RTPEngine engagement for media relay
5. Forward to destination via public interface

### Registration Flow
1. SIP client sends REGISTER to `sip:ast1.sandboxegytelecoms.com`
2. Kamailio performs domain lookup
3. Forwards REGISTER to mapped Asterisk server (10.10.40.117)
4. Asterisk handles authentication and registration

## Security Features

### VPN Source Detection
The `CHECK_VPN_SOURCE` route identifies traffic from VPN networks:
- `10.10.50.0/23` - Main VPN network
- `10.10.40.0/24` - Internal server network

### Loop Prevention
Multiple Via header checking prevents routing loops:
```kamailio
if ($(hdr(Via)[1]) =~ "c5.sandboxegytelecoms.com") {
    sl_send_reply("482","Loop Detected");
    exit;
}
```

### NAT Handling
- Force rport for proper NAT traversal
- RTPEngine for media relay
- Contact alias for NAT clients

## Monitoring and Troubleshooting

### View Real-time Logs
```bash
tail -f /var/log/syslog | grep kamailio
```

### Check Server Mappings
```bash
kamctl fifo htable.dump asterisk_servers
```

### Test Domain Resolution
```bash
# From Kamailio server
ping 10.10.40.117
ping ast1.sandboxegytelecoms.com
```

### Verify VPN Connectivity
```bash
# Test VPN connectivity to Asterisk
nc -zv 10.10.40.117 5060
```

### SIP Trace
```bash
sngrep -d lo  # Local loopback
sngrep -d eth0  # External interface
```

## Load Balancing (Future Enhancement)

For load balancing across multiple Asterisk servers, consider:

1. **Round-robin DNS**: Multiple A records for the same domain
2. **Dispatcher Module**: Use Kamailio's dispatcher for active load balancing
3. **Custom Logic**: Implement custom load distribution in routing logic

Example dispatcher configuration:
```kamailio
loadmodule "dispatcher.so"

modparam("dispatcher", "list_file", "/etc/kamailio/dispatcher.list")
modparam("dispatcher", "flags", 2)
modparam("dispatcher", "dst_avp", "$avp(AVP_DST)")
```

Dispatcher list file:
```
# Set 1: Asterisk servers
1 sip:10.10.40.117:5060 0 0
1 sip:10.10.40.118:5060 0 0
1 sip:10.10.40.119:5060 0 0
```

## Network Diagram

```
                         Internet
                            |
                            |
                    [Public Interface]
                    101.46.69.57:5060
                            |
                      [Kamailio]
                   c5.sandboxegytelecoms.com
                            |
                    [VPN Interface]
                    10.10.40.127
                            |
                    VPN: 10.10.50.0/23
                            |
        +-------------------+-------------------+
        |                   |                   |
   [Asterisk 1]        [Asterisk 2]        [Asterisk 3]
   10.10.40.117        10.10.40.118        10.10.40.119
   ast1.sandbox...     ast2.sandbox...     ast3.sandbox...
```

## Configuration Variables Reference

| Variable | Value | Description |
|----------|-------|-------------|
| `VPN_NETWORK` | 10.10.50.0/23 | VPN network range |
| `KAMAILIO_VPN_IP` | 10.10.40.127 | Kamailio's VPN interface IP |
| `ASTERISK_IP` | 10.10.40.117 | Default/Primary Asterisk server |
| `ASTERISK_PORT` | 5060 | SIP port for Asterisk servers |

## Best Practices

1. **Document All Changes**: Update this file when adding servers
2. **Test Before Production**: Always test new server additions
3. **Monitor Logs**: Watch for routing issues or misconfigurations
4. **Backup Configurations**: Keep backups before making changes
5. **Use Consistent Naming**: Follow the `astN` pattern for subdomains
6. **VPN Security**: Ensure VPN is properly secured and monitored

---
*Last Updated: October 23, 2025*
