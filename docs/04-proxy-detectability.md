# 04 — Can apps detect a transparent proxy?

Measured on a device running a root **TPROXY** proxy (sing-box under a vendor UI) with
`iptables` + policy routing, no `VpnService`.

## What TPROXY genuinely hides

| Signal | VPN/TUN mode | TPROXY |
|---|---|---|
| `NetworkCapabilities.hasTransport(TRANSPORT_VPN)` | `true` | **`false`** |
| VPN network in `getAllNetworks()` | present | **absent** |
| Extra `tun` in `NetworkInterface.getNetworkInterfaces()` | present | **absent** |
| Default route / MTU changed (1280) | yes | **unchanged** |
| `LinkProperties.getDnsServers()` replaced | yes | **unchanged** |
| System VPN icon / notification | yes | **no** |
| `Settings.Global.http_proxy` | possibly set | **unchanged** |
| TLS chain (if not MITM) | — | **normal** |

So the classic "VPN detection" heuristics fail against TPROXY.

## What still leaks

### 1. Loopback ports are open (cheapest, most reliable signal)

```
127.0.0.1:10810   mixed/http+socks inbound
127.0.0.1:65535   tproxy inbound (bound to ::)
127.0.0.1:46499   control API
```

Any app can `new Socket("127.0.0.1", 10810)` and confirm a local proxy exists — or even use it.
`a4-abox-lockdown` closes this from the app's perspective:

```
-A INPUT -i lo -p tcp --dport 10810 -j REJECT
-A INPUT -i lo -p tcp --dport 65535 -j REJECT     (v4 + v6)
```

Scanners then see **connection refused** instead of open. Only `iif lo` is affected, so
TPROXY delivery and hotspot sharing keep working.

### 2. The proxy app is installed

```java
getPackageManager().getPackageInfo("<proxy-app-package>", 0)
```

Removing this needs hiding the package (work profile, repackaging) — usually not worth it.

### 3. Egress IP contradicts the local link

```
egress      : 203.0.113.x  (datacenter ASN, US)
link IP     : 10.x.x.x     (carrier CGNAT)
timezone    : Asia/Shanghai
locale      : zh-Hans-CN
```

One HTTPS request yields all four. Datacenter ASN + geographic mismatch is the single most
common commercial proxy-detection feature.

### 4. DNS resolves remotely

If the final DNS server is a public resolver reached through the tunnel, a CDN hostname
resolves to a distant node. Apps can compare "system DNS answer" vs "DoH answer from the
same device".

## Techniques ranked by cost (from the app's side)

| Technique | Cost | Works against TPROXY? |
|---|---|---|
| Package name probe / loopback port scan | trivial | ✅ |
| Egress IP vs link IP + IP reputation | trivial | ✅ |
| Timezone / locale vs IP geolocation | low | ✅ |
| Self-DNS (DoH) then connect by IP | medium | ✅ |
| TCP/IP fingerprint (TTL, window, timestamps) | medium | ⚠️ weak — traffic leaves via a local socket, so the fingerprint matches a direct connection |
| TLS chain / pinning | medium | ❌ (no MITM) |
| `TRANSPORT_VPN` / tun / MTU heuristics | low | ❌ |

## Practical mitigations

1. Close the loopback ports (this repo's `a4`).
2. Put banking / payment / risk-sensitive apps on a **direct** rule — proxy detection there
   usually means refused service, not just a warning.
3. Egress via residential IPs or a nearby datacenter; keep timezone/locale plausible.
4. Do **not** enable fake-IP DNS unless necessary — it hands apps `198.18.x.x` answers, which
   is an unmistakable signature.
5. `sniff` + domain-based routing is fine; certificate MITM is what makes pinning fail.
