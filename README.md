# Kamailio Public Router

## Overview
This repository contains the configuration files for a Kamailio SIP server deployment used as a public router for Egytel telecommunications infrastructure. Each router is a standalone public endpoint, should be managed separately but working alongside with the other nodes.

## Project Description
Kamailio is an open-source SIP server that handles VoIP and real-time communication routing. This project manages the configuration and setup for our production Kamailio instance running on the public-facing router.

## Repository Contents

### Configuration Files
- **`kamailio.cfg`** - Main Kamailio configuration file containing routing logic, SIP handling rules, and server settings
- **`backup.kamailio.cfg.backup`** - Backup copy of the Kamailio configuration for rollback purposes
- **`kamctlrc`** - Kamailio control tool configuration file
- **`tls.cfg`** - TLS/SSL configuration for secure SIP communications (SIPS)
- **`test-sip-setup.sh`** - Script for testing SIP setup and connectivity
- **`server-mappings.conf`** - Documentation of Asterisk server domain-to-IP mappings

### Documentation Files
- **`README.md`** - This file, general project documentation
- **`NETWORKING.md`** - Detailed networking configuration and architecture documentation

### Management Scripts
- **`manage-servers.sh`** - Interactive script for managing Asterisk server mappings and testing connectivity

## Server Information
- **Remote Server**: c5.sandboxegytelecoms.com
- **Configuration Path**: /etc/kamailio/
- **Access**: Root user access required for configuration management

## Network Configuration
- **VPN Network**: 10.10.50.0/23
- **Kamailio VPN IP**: 10.10.40.127
- **Primary Asterisk**: 10.10.40.117 (ast1.sandboxegytelecoms.com)
- **Public IP**: 101.46.69.57

### Domain-Based Routing
Kamailio uses domain-to-IP mapping for routing to multiple Asterisk servers:
- Each Asterisk server has a public domain/subdomain
- Kamailio maintains a hash table mapping domains to VPN IPs
- Easy to add new servers by updating the configuration

See **[NETWORKING.md](NETWORKING.md)** for detailed architecture and configuration.

## Workflow

### Syncing Configuration from Server
To sync the latest configuration files from the remote server:
```bash
rsync -avz --progress root@c5.sandboxegytelecoms.com:/etc/kamailio/ .
```

### Deploying Configuration to Server
To deploy local changes to the remote server:
```bash
rsync -avz --progress ./ root@c5.sandboxegytelecoms.com:/etc/kamailio/
```

### Restarting Kamailio Service
After configuration changes:
```bash
ssh root@c5.sandboxegytelecoms.com "systemctl restart kamailio"
```

### Checking Service Status
```bash
ssh root@c5.sandboxegytelecoms.com "systemctl status kamailio"
```

### Managing Asterisk Servers
Use the management script to add/test servers:
```bash
# On the remote server
sudo ./manage-servers.sh
```

The script provides:
- View current server mappings
- Add new Asterisk servers
- Test server connectivity
- Check routing configuration
- View logs and status

## Best Practices

1. **Always Backup**: Create backups before making changes
2. **Test Configuration**: Validate syntax before deploying
3. **Version Control**: Commit all changes to Git with descriptive messages
4. **Review Logs**: Monitor Kamailio logs after configuration changes
5. **Document Changes**: Update README and NETWORKING.md when adding servers
6. **Use Management Script**: Leverage manage-servers.sh for consistency

## Configuration Management

### Testing Configuration Syntax
Before deploying, validate configuration syntax:
```bash
ssh root@c5.sandboxegytelecoms.com "kamailio -c -f /etc/kamailio/kamailio.cfg"
```

### Creating a Backup
```bash
ssh root@c5.sandboxegytelecoms.com "cp /etc/kamailio/kamailio.cfg /etc/kamailio/backup.kamailio.cfg.backup"
```

## Troubleshooting

### View Real-time Logs
```bash
ssh root@c5.sandboxegytelecoms.com "tail -f /var/log/syslog | grep kamailio"
```

### Check for Configuration Errors
```bash
ssh root@c5.sandboxegytelecoms.com "journalctl -u kamailio -n 50"
```

## Security Notes
- TLS is configured in `tls.cfg` for secure communications
- Ensure firewall rules allow SIP traffic (ports 5060/5061)
- Keep configuration files secure and avoid exposing sensitive data in public repositories

## Contributing
When making changes:
1. Create a feature branch
2. Make and test your changes locally
3. Commit with clear descriptions
4. Test on the remote server
5. Document any new features or changes

## Contact
For questions or issues related to this Kamailio deployment, contact the Egytel infrastructure team.

## License
Internal use only - Egytel Telecommunications

---
*Last Updated: October 21, 2025*
