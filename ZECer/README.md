# 📘 ZECer Connectivity & Network Troubleshooting Report

**Project:** ZECer (Native iOS Zcash Wallet)  
**Tech Stack:** Swift, SwiftUI, ZcashLightClientKit (ECC SDK)  
**Environment:** iOS 18+, Physical iPhone (India Region)  
**Network Constraints:** High-Restriction ISP Environment (Deep Packet Inspection / DNS Blocking / Active Probing)  
**Date:** January 2026

---

## 1. Executive Summary
The objective was to build a native iOS Zcash wallet capable of syncing with the Mainnet. While the core application logic was successfully implemented, the project encountered severe network-level blockades.

The troubleshooting process exhausted the entire OSI model, from Application layer timeouts to Transport layer encryption (Tor). We successfully bypassed the ISP using Tor, but failed at the protocol level due to Tor Exit Node blocking and the SDK's lack of compiled support for Onion Services.

---

## 2. Inventory of Targets & Configurations

Before detailing the chronology, here is the complete list of endpoints and settings tested.

### 2.1 RPC Nodes & Endpoints Attempted
| Node Name | Address / IP | Port | Protocol | Result |
| :--- | :--- | :--- | :--- | :--- |
| **ECC Testnet** | `lightwalletd.testnet.electriccoin.co` | 9067 | TCP/TLS | 🔴 SSL/ATS Fail |
| **ECC Mainnet** | `mainnet.lightwalletd.com` | 443 | TCP/TLS | 🔴 Timeout / DNS Fail |
| **Nighthawk** | `zcash.adityapk.com` | 443 | TCP/TLS | 🔴 Timeout |
| **ZecRocks** | `mainnet.zec.rocks` | 443 | TCP/TLS | 🔴 Timeout |
| **Infrastructure** | `lwd1.zcash-infra.com` | 443 | TCP/TLS | 🔴 Timeout |
| **Asia Pacific** | `ap.lightwalletd.com` | 443 | TCP/TLS | 🔴 Timeout |
| **ECC Direct IP** | `35.235.105.143` | 443 | TCP/TLS | 🔴 Blocked (Direct & Tor) |
| **Nighthawk IP** | `5.9.61.233` | 443 | TCP/TLS | 🔴 Blocked (Tor Exit) |
| **ZecRocks Onion**| `zcashnodesib... .onion` | 80 | Tor Hidden Service | 🔴 SDK Feature Missing |

### 2.2 iOS Network "Tricks" & Settings Modified
| Setting / Tool | Configuration | Result |
| :--- | :--- | :--- |
| **iCloud Private Relay** | **Disabled** (To prevent Apple routing interference) | 🔴 No Change |
| **Limit IP Address Tracking** | **Disabled** (Wi-Fi Settings) | 🔴 No Change |
| **Private Wi-Fi Address** | **Disabled** (MAC Address Randomization off) | 🔴 No Change |
| **DNS Configuration** | Manual override to `8.8.8.8` (Google) & `1.1.1.1` | 🔴 Failed (ISP Intercept) |
| **Airplane Mode Toggle** | Hard network reset between attempts | 🔴 No Change |
| **USB Tethering** | Connected via Mac to bypass Wi-Fi radio stack | 🔴 No Change |

---

## 3. Detailed Troubleshooting Chronology

### Phase 1: Testnet Initialization
**Objective:** Connect to Zcash Testnet.
* **Result:** 🔴 **FAILED**
* **Error:** `SSL Handshake Failed`. Apple ATS rejected the Testnet certificate chain.
* **Decision:** Abandon Testnet for Mainnet.

### Phase 2: Mainnet Stability (The "History" Crash)
**Objective:** Prevent app crash on startup.
* **Issue:** Default SDK settings attempted to scan 8 years of blockchain history (from Block 0), causing OOM (Out of Memory) crashes.
* **Fix:** Implemented **"Birthday Fix"** (Hardcoded `BlockHeight(2750000)`).
* **Result:** ✅ **SUCCESS** (Engine initialized).

### Phase 3: The ISP Blockade (DPI & Timeouts)
**Objective:** Complete gRPC handshake via direct connection.
* **Targets:** All standard domains (`lightwalletd.com`, `zec.rocks`, `adityapk.com`).
* **Result:** 🔴 **FAILED**
* **Error:** `serviceGetInfoFailed(... timeOut)`.
* **Analysis:** ISP Deep Packet Inspection (DPI) identified gRPC headers and dropped packets.

### Phase 4: VPNs & Privacy Overlays
**Objective:** Tunnel traffic to bypass DPI.
* **Attempt 4.1 (Cloudflare WARP):** 🔴 FAILED.
* **Attempt 4.2 (NordVPN Standard - UDP):** 🔴 FAILED (Latency >300ms triggered SDK timeout).
* **Attempt 4.3 (NordVPN Obfuscated - TCP/Singapore):** 🔴 FAILED. Handshake failed via "Server not found" (DNS Leak).
* **Attempt 4.4 (Nym Mixnet):** 🔴 FAILED. Mixnet latency was too high for gRPC keep-alive.

### Phase 5: "Zashi" Config & DNS Hardening
**Objective:** Replicate official wallet settings and fix DNS.
* **Action:** Increased SDK timeouts to 60s/120s. Manually set DNS to 8.8.8.8. Disabled all Apple privacy proxies.
* **The "Safari Test":** Visiting `https://mainnet.lightwalletd.com/` in Safari failed with **"Server cannot be found."**
* **Conclusion:** ISP is intercepting DNS requests regardless of VPN settings on iOS.

### Phase 6: The Cloudflare Bridge (Proxy)
**Objective:** Use Cloudflare Workers to mask traffic.
* **Attempt 6.1 (Standard):** 🔴 FAILED (`Error 1016: Origin DNS Error`). Cloudflare couldn't resolve Zcash domains.
* **Attempt 6.2 (Direct IP):** 🔴 FAILED (`Error 1003`). Cloudflare forbids Direct IP access.
* **Attempt 6.3 (Infra Node):** 🔴 FAILED. Cloudflare blocks crypto RPC ports on free tier.

### Phase 7: The Tor Breakthrough
**Objective:** Use embedded `Arti` Tor client.
* **Result:** ✅ **SUCCESS**
* **Log:** `arti_client::status: 100%: connecting successfully; directory is usable`.
* **Significance:** We successfully bypassed the ISP firewall.

### Phase 8: Tor Exit Node Failures (DNS)
**Objective:** Connect via Tor using Domain Names.
* **Target:** `mainnet.zec.rocks` (via Tor).
* **Result:** 🔴 **FAILED**
* **Error:** `tor: remote hostname lookup failure`.
* **Analysis:** Tor Exit Nodes failed to resolve the DNS, or the Exit Nodes were blocked by the target.

### Phase 9: Tor + Direct IP (Bypassing DNS)
**Objective:** Connect via Tor using raw IP addresses (No DNS).
* **Target 1:** `35.235.105.143` (Google Cloud / ECC).
* **Target 2:** `5.9.61.233` (Hetzner / Nighthawk).
* **Result:** 🔴 **FAILED**
* **Error:** `tor: operation timed out at exit: Timed out while waiting for answer from exit`.
* **Analysis:** 1.  **Google Cloud** explicitly blocks connections from known Tor Exit Nodes.
    2.  **Hetzner** or the Nighthawk firewall also dropped the connection from the Exit Node.

### Phase 10: The Onion Service (Final Attempt)
**Objective:** Use a Hidden Service (`.onion`) to eliminate Exit Nodes entirely.
* **Target:** `zcashnodesib... .onion` (ZecRocks Hidden Service).
* **Result:** 🔴 **CRITICAL FAILURE**
* **Error:** `tor: operation not supported because Arti feature disabled: Rejecting .onion address; feature onion-service-client not compiled in`.
* **Root Cause:** The `ZcashLightClientKit` was compiled with the `onion-service-client` feature **disabled** to reduce binary size. Re-enabling this requires forking and recompiling the Rust SDK.

---

## 4. Final Verdict
The project is blocked by a combination of three hostile layers:
1.  **Local ISP:** Blocks direct gRPC and DNS (Bypassed via Tor).
2.  **Cloud Providers:** Block Tor Exit Nodes (Bypassed via Onion Services).
3.  **Client SDK:** Lacks compilation support for Onion Services (Fatal Flaw).

**Recommendation:** Proceed with the **Offline Signer / Air-Gapped Architecture**.
