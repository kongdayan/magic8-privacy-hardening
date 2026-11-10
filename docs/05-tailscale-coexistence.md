# 05 — Running Tailscale and a TPROXY proxy at the same time

Goal: keep a Tailscale connection **and** a transparent proxy working, without either breaking
the other. Measured on Android 17 with Tailscale (`VpnService`, interface `tun1`) plus a root
TPROXY proxy.

## The two mechanisms are not the same layer

| | Tailscale on Android | Root TPROXY proxy |
|---|---|---|
| Mechanism | `VpnService` (userspace tun) | `netfilter` hooks + policy routing |
| Needs | VPN permission | root |
| Sees app traffic via | tun device | `OUTPUT` / `PREROUTING` |
| Conflicts with | another `VpnService` | another `TPROXY`/`fwmark` setup |

## Order of evaluation

For an outbound packet the kernel evaluates **netfilter `OUTPUT` before the routing decision**.
So the proxy's `OUTPUT` chain decides first; only packets it `RETURN`s proceed to routing and
possibly into `tun1`.

```
app socket
├─ destination in 100.64.0.0/10 or Tailscale IPv6 range
│    OUTPUT: -d 100.64.0.0/10 -j RETURN        (already present in bypass CIDRs)
│    → ip rule → per-app table → tun1 → tailscaled
│       ↳ tailscaled's own encrypted packets are uid-owned by the Tailscale app
│         → -m owner --uid-owner <tailscale-uid> -j RETURN   (what we add)
│    → physical interface (direct or via DERP)
│
└─ any other destination
     OUTPUT → MARK → TPROXY → sing-box → routing rules → physical interface
```

Practical reading: **the proxy is in front; Tailscale only owns the 100.64/10 slice.**

## Why the per-app UID exclusion is required

Tailscale's own transport packets (DERP, coordination, peer WireGuard) go to **public** IPs via
the physical interface. They are not inside `100.64.0.0/10`, so the proxy would capture them —
breaking Tailscale (or double-proxying it).

On Linux/OpenWrt you exclude the interface (`iifname != "tailscale0"`). On Android there is no
such interface to match: the encrypted packets are emitted by the Tailscale **process**, so the
exclusion must be by UID:

```bash
su -c 'cmd appops ...'                      # not this
# instead, in the proxy app: per-app list → blacklist mode → add Tailscale
# generated rule:
-A ASTERISK_TPROXY_OUTPUT -m owner --uid-owner <tailscale-uid> -j RETURN
```

Verify:

```bash
lsof ...                              # or: ip rule; ss -tan
ping -c2 <tailscale-peer-ip>          # tailnet reachable, 0% loss
curl -m5 https://<blocked-host>       # still rejected  → proxy still active
```

## The hard limit: exit node mode

If the phone selects a Tailscale **exit node**, Tailscale installs `0.0.0.0/0` into `tun1`.
Every packet then enters the VPN, and the proxy sees only tailscaled's encrypted stream — which
we deliberately excluded. Result: the proxy is effectively bypassed.

| Configuration | Full-tunnel | Ad/tracker blocking | Note |
|---|:---:|:---:|---|
| Tailscale as tailnet access only + TPROXY proxy | ✗ | ✅ | the coexistence setup above |
| Tailscale exit node | ✅ | ✗ | proxy bypassed by design |
| Proxy sends its own egress through `tun1` | ✅ | ✅ | needs `route.override_android_vpn`; one extra hop, must be measured |

The third row is the interesting one: if the proxy's **outbound** is allowed to bind to the
Android VPN, its traffic exits through Tailscale while still applying its own rules. That gives
full-tunnel *and* blocking, at the cost of an extra hop and a dependency on the VPN staying up.

## Checklist

- [x] tailnet destinations excluded from the proxy (`100.64.0.0/10` in bypass CIDRs)
- [x] Tailscale UID excluded from TPROXY
- [x] proxy still blocking (probe a known tracker domain)
- [x] tailnet reachable in both directions
- [ ] if exit node is used, accept that the proxy is inactive (or use `override_android_vpn`)
