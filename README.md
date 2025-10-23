# Kamailio Public Router

## Overview
This repository contains the configuration files for a Kamailio SIP server deployment used as a public router for Egytel telecommunications infrastructure. Each router is a standalone public endpoint, should be managed separately but working alongside with the other nodes.

## Project Description
Kamailio is an open-source SIP server that handles VoIP and real-time communication routing. This project manages the configuration and setup for our production Kamailio instance running on the public-facing router.

## Repository Contents

### Configuration Files
- **`kamailio.cfg`** - Main Kamailio configuration file containing routing logic, SIP handling rules, and server settings
- **`backup.kamailio.cfg.backuscp c5.sandboxegytelecoms.com:/etc/kamailio/kamailio.cfg /home/ahmed/Documents/Egytel/kamailio-public-router/p`** - Backup copy of the Kamailio configuration for rollback purposes
- **`kamctlrc`** - Kamailio control tool configuration file
- **`tls.cfg`** - TLS/SSL configuration for secure SIP communications (SIPS)
- **`test-sip-setup.sh`** - Script for testing SIP setup and connectivity

## Server Information
- **Remote Server**: c5.sandboxegytelecoms.com
- **Configuration Path**: /etc/kamailio/
- **Access**: Root user access required for configuration management

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

## Best Practices

1. **Deploy To Test**: Test configuration by deploying it to the remote server
2. **Version Control**: Commit all changes to Git with descriptive messages
3. **Review Logs**: Monitor Kamailio logs after configuration changes
4. **Document Changes**: Update this README when adding new configurations or scripts

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
