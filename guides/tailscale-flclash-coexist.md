# Android Tailscale & FlClash/ClashMeta Coexistence Guide

> **Goal**: Eliminate Android `VpnService` conflicts between Proxy tools (FlClash / ClashMeta / Surfboard) and Tailscale mesh VPN, ensuring sub-5ms low latency direct P2P connections to your remote AI workstation.

---

## 1. Problem Anatomy & Root Cause

Android's architecture enforces a strict **Single Active `VpnService` Constraint**:
- Only one application can bind to the Android system VPN interface at any given time.
- If FlClash captures the global TUN interface, Tailscale cannot establish its native OS-level VPN slot simultaneously.
- When both are active (e.g., using Tailscale as a standalone service or routing Tailscale IP ranges through Clash), misconfigured routing rules route CGNAT traffic (`100.64.0.0/10`) through remote proxy nodes, turning a <5ms local Wi-Fi/5G Direct link into a 200–500ms multi-hop relay.

---

## 2. Architecture & Solution Models

There are two primary architectures to achieve seamless coexistence:

### Pattern A: Clash TUN Mode with Direct Bypass & App Exclusion (Recommended)

In this model, FlClash / ClashMeta holds the system `VpnService`, while Tailscale traffic and the Tailscale package are exempted from proxying and routed straight through the local interface.

#### 1. Rule Configuration in Clash / Merge.yaml

Add the Tailscale CGNAT IPv4 and IPv6 subnets to the top of your Clash rules as `DIRECT`:

```yaml
rules:
  # === Tailscale CGNAT & Local Subnets Direct Route ===
  - IP-CIDR,100.64.0.0/10,DIRECT,no-resolve
  - IP-CIDR6,fd7a:115c:a1e0::/48,DIRECT,no-resolve
  
  # === Local LAN Subnets ===
  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve
  - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
  - IP-CIDR,172.16.0.0/12,DIRECT,no-resolve
  
  # Remote AI Agent API rules (if applicable)
  - DOMAIN-SUFFIX,anthropic.com,AI-Proxy
  - DOMAIN-SUFFIX,openai.com,AI-Proxy
  - MATCH,DIRECT
```

#### 2. FlClash / Clash App Bypass Configuration

In FlClash / ClashMeta Android client settings:
1. Navigate to **Settings** -> **Network / TUN Settings** -> **Access Control / App Bypass**.
2. Select **Bypass Mode (Blacklist)** or **Excluded Apps**.
3. Check and exclude:
   - `com.tailscale.ipn` (Tailscale Android Client)
   - `com.termux` (Termux Terminal - Optional, only if Termux does not need global web proxy)
4. Ensure **Route Address / Bypass Subnet** includes `100.64.0.0/10`.

---

### Pattern B: Termux-Native Tailscale (Userspace Engine)

If you need FlClash to manage global mobile traffic while Termux directly communicates over Tailscale without using Android's system `VpnService`:

1. Install `tailscale` inside Termux:
   ```bash
   pkg install tailscale
   ```
2. Start `tailscaled` in userspace-networking (SOCKS5/Tunless) mode:
   ```bash
   tailscaled --tun=userspace-networking --socks5-server=localhost:1055 &
   tailscale up --accept-routes
   ```
3. Route SSH through the local SOCKS5 proxy:
   ```bash
   ssh -o "ProxyCommand=nc -X 5 -x 127.0.0.1:1055 %h %p" user@100.x.y.z
   ```

---

## 3. Verifying WireGuard P2P Handshake & Sub-5ms Latency

To ensure traffic is not relaying through a DERP server or external proxy:

### Step 1: Check Tailscale Peer Status
Run on your mobile device or remote host:
```bash
tailscale status
```

Expected output for direct P2P connection:
```text
100.100.1.25   workstation-mac  steven@  macOS   active; direct 192.168.1.50:41641, tx 1024 rx 2048
```
> **Key Indicator**: The presence of `direct <IP>:<PORT>` signifies a direct WireGuard UDP tunnel. If it shows `relay "lax"` or `derp-X`, the connection is relayed.

### Step 2: Ping & Latency Probe
```bash
tailscale ping 100.x.y.z
```
Output breakdown:
```text
pong from workstation (100.x.y.z) via 192.168.1.50:41641 in 2ms   <-- Direct P2P (< 5ms)
pong from workstation (100.x.y.z) via DERP(tok) in 85ms           <-- Relayed (> 50ms)
```

### Step 3: UDP Firewall / Port Punching Optimization
To guarantee direct P2P handshake:
- On your home router, enable **Full Cone NAT (NAT1)** or configure port forwarding for Tailscale UDP port `41641`.
- Avoid Symmetric NAT when both devices are under cellular networks.

---

## 4. Checklist for Low-Latency AI Agent Operations

| Item | Target State | Failure Mode |
| :--- | :--- | :--- |
| **Routing Rule** | `100.64.0.0/10 -> DIRECT` | Traverses proxy, 200ms+ latency |
| **Tunnel State** | `active; direct <ip>:<port>` | DERP relaying, unstable typing |
| **KeepAlive** | `ServerAliveInterval=5` | Connection drops on cellular switch |
| **MTU Size** | 1280 (Default Tailscale WireGuard) | Packet fragmentation & TUI freeze |
