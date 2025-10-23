# Kamailio Network Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         INTERNET                                 │
│                    (Public SIP Clients)                          │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           │ SIP Traffic
                           │ UDP/TCP: 5060
                           │ TLS: 5061
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                    PUBLIC INTERFACE                              │
│             c5.sandboxegytelecoms.com                           │
│                  101.46.69.57                                    │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐   │
│  │              KAMAILIO SIP PROXY                         │   │
│  │  ┌──────────────────────────────────────────────────┐  │   │
│  │  │  Domain-Based Routing Engine                     │  │   │
│  │  │  • ast1.sandboxegytelecoms.com → 10.10.40.117  │  │   │
│  │  │  • ast2.sandboxegytelecoms.com → 10.10.40.118  │  │   │
│  │  │  • ast3.sandboxegytelecoms.com → 10.10.40.119  │  │   │
│  │  └──────────────────────────────────────────────────┘  │   │
│  │                                                          │   │
│  │  ┌──────────────────────────────────────────────────┐  │   │
│  │  │  RTPEngine (Media Relay)                         │  │   │
│  │  │  • NAT Traversal                                 │  │   │
│  │  │  • Media Proxying                                │  │   │
│  │  └──────────────────────────────────────────────────┘  │   │
│  └────────────────────────────────────────────────────────┘   │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           │ VPN Interface
                           │ 10.10.40.127
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                   VPN NETWORK                                    │
│              10.10.50.0/23 & 10.10.40.0/24                      │
│                                                                  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐│
│  │  Asterisk 1     │  │  Asterisk 2     │  │  Asterisk 3     ││
│  │  10.10.40.117  │  │  10.10.40.118  │  │  10.10.40.119  ││
│  │                 │  │                 │  │                 ││
│  │  ast1.sandbox  │  │  ast2.sandbox  │  │  ast3.sandbox  ││
│  │  egytelecoms   │  │  egytelecoms   │  │  egytelecoms   ││
│  │  .com           │  │  .com           │  │  .com           ││
│  │                 │  │                 │  │                 ││
│  │  ┌───────────┐ │  │  ┌───────────┐ │  │  ┌───────────┐ ││
│  │  │ SIP Users │ │  │  │ SIP Users │ │  │  │ SIP Users │ ││
│  │  │ Trunks    │ │  │  │ Trunks    │ │  │  │ Trunks    │ ││
│  │  │ Dialplan  │ │  │  │ Dialplan  │ │  │  │ Dialplan  │ ││
│  │  └───────────┘ │  │  └───────────┘ │  │  └───────────┘ ││
│  └─────────────────┘  └─────────────────┘  └─────────────────┘│
│                                                                  │
│         [Active]           [Planned]          [Planned]         │
└──────────────────────────────────────────────────────────────────┘
```

## Traffic Flow Diagrams

### Inbound Call Flow (Internet → VPN)

```
External SIP Client                Kamailio              Asterisk
(203.0.113.45)           (10.10.40.127 / 101.46.69.57)  (10.10.40.117)
      │                              │                         │
      │ INVITE                       │                         │
      │ sip:1000@ast1.sandbox...com  │                         │
      ├─────────────────────────────►│                         │
      │                              │                         │
      │                              │ 1. NAT Detection        │
      │                              │ 2. Domain Lookup:       │
      │                              │    ast1.sandbox...com   │
      │                              │    → 10.10.40.117      │
      │                              │ 3. RTPEngine (Offer)    │
      │                              │                         │
      │                              │ INVITE                  │
      │                              │ Via VPN                 │
      │                              ├────────────────────────►│
      │                              │                         │
      │                              │                         │ Auth/
      │                              │                         │ Process
      │                              │                         │
      │                              │         200 OK          │
      │                              │◄────────────────────────┤
      │                              │                         │
      │                              │ RTPEngine (Answer)      │
      │         200 OK               │                         │
      │◄─────────────────────────────┤                         │
      │                              │                         │
      │         ACK                  │         ACK             │
      ├─────────────────────────────►├────────────────────────►│
      │                              │                         │
      │═══════════════════════════════════════════════════════►│
      │          RTP Media (via RTPEngine)                     │
      │◄═══════════════════════════════════════════════════════│
```

### Outbound Call Flow (VPN → Internet)

```
Asterisk              Kamailio              External Destination
(10.10.40.117)  (10.10.40.127 / 101.46.69.57)  (SIP Provider)
      │                   │                         │
      │ INVITE            │                         │
      │ To External       │                         │
      ├──────────────────►│                         │
      │                   │                         │
      │                   │ 1. Detect VPN Source    │
      │                   │ 2. RTPEngine (Offer)    │
      │                   │ 3. Route to Public      │
      │                   │                         │
      │                   │         INVITE          │
      │                   ├────────────────────────►│
      │                   │                         │
      │                   │         200 OK          │
      │                   │◄────────────────────────┤
      │                   │                         │
      │                   │ RTPEngine (Answer)      │
      │      200 OK       │                         │
      │◄──────────────────┤                         │
      │                   │                         │
      │       ACK         │         ACK             │
      ├──────────────────►├────────────────────────►│
      │                   │                         │
      │═══════════════════════════════════════════►│
      │      RTP Media (via RTPEngine)              │
      │◄═══════════════════════════════════════════│
```

### Registration Flow

```
SIP Client                    Kamailio              Asterisk
(External)         (10.10.40.127 / 101.46.69.57)  (10.10.40.117)
      │                           │                      │
      │ REGISTER                  │                      │
      │ To: ast1.sandbox...com    │                      │
      ├──────────────────────────►│                      │
      │                           │                      │
      │                           │ Domain Lookup:       │
      │                           │ ast1.sandbox...com   │
      │                           │ → 10.10.40.117      │
      │                           │                      │
      │                           │    REGISTER          │
      │                           ├─────────────────────►│
      │                           │                      │
      │                           │                      │ Auth
      │                           │                      │ Check
      │                           │                      │
      │                           │    401 Unauthorized  │
      │                           │◄─────────────────────┤
      │    401 Unauthorized       │                      │
      │◄──────────────────────────┤                      │
      │                           │                      │
      │ REGISTER (with auth)      │                      │
      ├──────────────────────────►│                      │
      │                           │                      │
      │                           │ REGISTER (with auth) │
      │                           ├─────────────────────►│
      │                           │                      │
      │                           │       200 OK         │
      │                           │◄─────────────────────┤
      │       200 OK              │                      │
      │◄──────────────────────────┤                      │
      │                           │                      │
```

## Network Zones

```
┌─────────────────────────────────────────────────────────────┐
│  PUBLIC ZONE                                                 │
│  • Internet-facing                                           │
│  • Public IP: 101.46.69.57                                  │
│  • Ports: 5060 (UDP/TCP), 5061 (TLS)                       │
│  • NAT clients supported                                     │
└─────────────────────────────────────────────────────────────┘
                            │
                    ┌───────┴───────┐
                    │   KAMAILIO    │
                    │  (Firewall)   │
                    └───────┬───────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│  VPN ZONE                                                    │
│  • Internal network: 10.10.50.0/23                          │
│  • Server subnet: 10.10.40.0/24                             │
│  • Encrypted VPN tunnels                                     │
│  • No direct public access                                   │
│  • All Asterisk servers here                                 │
└─────────────────────────────────────────────────────────────┘
```

## Routing Decision Tree

```
                        SIP Request Arrives
                               │
                               ▼
                    ┌──────────────────────┐
                    │  Initial Checks      │
                    │  • Max forwards      │
                    │  • Sanity check      │
                    └──────────┬───────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │  NAT Detection       │
                    │  Check source IP     │
                    └──────────┬───────────┘
                               │
                ┌──────────────┴──────────────┐
                │                             │
                ▼                             ▼
    ┌──────────────────┐        ┌──────────────────────┐
    │  VPN Source      │        │  Public Source       │
    │  10.10.x.x       │        │  External IP         │
    └────────┬─────────┘        └──────────┬───────────┘
             │                              │
             │                              │ Set NAT flag
             │                              │ Fix Contact
             └──────────────┬───────────────┘
                            │
                            ▼
                ┌───────────────────────┐
                │  Method Check         │
                └───────────┬───────────┘
                            │
          ┌─────────────────┼─────────────────┐
          │                 │                 │
          ▼                 ▼                 ▼
    ┌─────────┐      ┌──────────┐     ┌──────────┐
    │REGISTER │      │  INVITE  │     │  Other   │
    └────┬────┘      └────┬─────┘     └────┬─────┘
         │                │                 │
         ▼                ▼                 ▼
    Domain Lookup    Domain Lookup    Domain Lookup
         │                │                 │
         ▼                ▼                 ▼
    ┌────────────────────────────────────────┐
    │  Check Hash Table                      │
    │  $sht(asterisk_servers=>domain)       │
    └────────────┬───────────────────────────┘
                 │
      ┌──────────┴──────────┐
      │                     │
      ▼                     ▼
  ┌────────┐         ┌──────────────┐
  │ Found  │         │  Not Found   │
  │ Use IP │         │  Use Default │
  └───┬────┘         └──────┬───────┘
      │                     │
      └──────────┬──────────┘
                 │
                 ▼
        ┌──────────────────┐
        │  Engage RTPEngine│
        │  (if has SDP)    │
        └────────┬─────────┘
                 │
                 ▼
        ┌──────────────────┐
        │  Forward to      │
        │  Asterisk Server │
        └──────────────────┘
```

## Security Layers

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: Network Firewall                                   │
│  • Allow only SIP ports (5060, 5061)                        │
│  • Rate limiting                                             │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│  Layer 2: Kamailio Security                                  │
│  • Max-Forwards check (prevent loops)                       │
│  • SIP sanity checks (malformed messages)                   │
│  • Via header loop detection                                │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: VPN Isolation                                      │
│  • Asterisk servers in isolated VPN                         │
│  • No direct public access                                   │
│  • Encrypted VPN tunnels                                     │
└─────────────────────────────────────────────────────────────┘
                            │
┌─────────────────────────────────────────────────────────────┐
│  Layer 4: Asterisk Authentication                            │
│  • SIP digest authentication                                 │
│  • User/password verification                                │
│  • Registration expiry management                            │
└─────────────────────────────────────────────────────────────┘
```

---
*Last Updated: October 23, 2025*
