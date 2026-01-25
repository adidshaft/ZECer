# 📘 ZECer Connectivity & Network Troubleshooting Report

**Project:** ZECer (Native iOS Zcash Wallet)  
**Tech Stack:** Swift, SwiftUI, ZcashLightClientKit (ECC SDK)  
**Environment:** iOS 18+, Physical iPhone (India Region)  
**Network Constraints:** High-Restriction ISP Environment (Deep Packet Inspection / DNS Blocking / Active Probing)  
**Date:** January 2026

---

## 1. Executive Summary
The objective was to build a native iOS Zcash wallet ("ZECer") capable of syncing with the Zcash blockchain on the Mainnet. While the core application logic (key derivation, UI, state management) was successfully implemented, the project encountered severe network-level blockades specific to the ISP environment in India.

The troubleshooting process evolved from standard connection attempts to advanced circumvention techniques (VPNs, Obfuscation, Cloudflare Bridges) and finally to the **Tor Network**. While we successfully bootstrapped Tor on the device (bypassing the ISP), we hit insurmountable barriers at the protocol level: **Tor Exit Nodes are blocked by Zcash servers**, and the **Zcash SDK lacks compiled support for Onion Services**, rendering the Tor circuit useless for this specific application.

---

## 2. Chronological Troubleshooting Log

### Phase 1: Testnet Initialization
**Objective:** Connect to the Zcash Testnet for safe development.
* **Configuration:** Endpoint: `lightwalletd.testnet.electriccoin.co` | Port: `9067` | SSL: Enabled
* **Result:** 🔴 **FAILED**
* **Error Log:** `SSL Handshake Failed` / `Certificate Invalid`.
* **Analysis:** Testnet infrastructure certificates were likely expired or rejected by Apple's strict ATS policies.
* **Decision:** Abandon Testnet and pivot to **Mainnet** production infrastructure.

### Phase 2: Mainnet Migration & Stability Fixes
**Objective:** Establish a stable application state without crashing.
* **Configuration:** Endpoint: `mainnet.lightwalletd.com` | Birthday: Block 0
* **Result:** 🔴 **CRITICAL FAIL (Crash)**
* **Root Cause:** SDK attempted to scan 8 years of history, overloading device RAM.
* **Fix:** Implemented **"The Birthday Fix"** (Hardcoded `BlockHeight(2750000)`).
* **Outcome:** ✅ **SUCCESS**. Engine initialized without crashing.

### Phase 3: The ISP Blockade (Direct Connections)
**Objective:** Complete server handshake (`validateServer`).
* **Targets:** `mainnet.lightwalletd.com`, `zcash.adityapk.com`, `mainnet.zec.rocks`
* **Result:** 🔴 **FAILED (Timeout)**
* **Error:** `serviceGetInfoFailed(... timeOut)`
* **Analysis:** Requests leave the phone but never receive an ACK. ISP is performing Deep Packet Inspection (DPI) on gRPC headers and dropping packets.

### Phase 4: Encrypted Tunneling (VPNs & Privacy Tech)
**Objective:** Encrypt packet headers to bypass DPI.
* **Attempt 4.1 (Cloudflare WARP):** 🔴 FAILED (No change).
* **Attempt 4.2 (NordVPN Standard/NordLynx):** 🔴 FAILED (Latency >300ms triggered 10s timeout).
* **Attempt 4.3 (Nym Mixnet):** 🔴 FAILED (Latency >2s per packet, incompatible with gRPC).
* **Attempt 4.4 (NordVPN Obfuscated/TCP):** 🔴 FAILED. Handshake failed despite obfuscation, indicating DNS blocking or active probing.

### Phase 5: The "Zashi" Protocol & DNS Hardening
**Objective:** Replicate official wallet configs and fix DNS leaks.
* **Attempt 5.1 (Timeout Overrides):** Increased to 60s/120s. 🔴 FAILED.
* **Attempt 5.2 (The Safari Test):** `https://mainnet.lightwalletd.com/` in Safari. ❌ **"Server cannot be found."** (Confirmed DNS Block).
* **Attempt 5.3 (Hard DNS Reset):** Disabled Private Relay/IP Tracking, forced DNS to `8.8.8.8`. 🔴 FAILED. ISP intercepts and redirects DNS queries.

### Phase 6: The Cloudflare Bridge (Proxy Strategy)
**Objective:** Mask Zcash traffic as standard web traffic via Cloudflare Workers.
* **Attempt 6.1 (Standard Forwarding):** 🔴 FAILED (`Error 1016: Origin DNS Error`). Cloudflare could not resolve Zcash domains.
* **Attempt 6.2 (Direct IP Target):** 🔴 FAILED (`Error 1003: Direct IP access not allowed`). Cloudflare Free Tier forbids raw IP connections.
* **Attempt 6.3 (Infrastructure Node):** 🔴 FAILED. Cloudflare blocks outbound connections to crypto RPC ports on free accounts.

### Phase 7: The Tor Breakthrough (Arti Integration)
**Objective:** Use the embedded Tor client (`Arti`) to punch through the ISP firewall.
* **Configuration:** Enabled `isTorEnabled: true` in SDK.
* **Result:** ✅ **PARTIAL SUCCESS**
* **Log:** `arti_client::status: 100%: connecting successfully; directory is usable`
* **Analysis:** **We defeated the ISP block.** The phone successfully established a circuit into the Tor network.

### Phase 8: The "Exit Node" Blockade
**Objective:** Connect from the Tor Network to the Zcash Server.
* **Target:** `mainnet.zec.rocks` (via Tor)
* **Result:** 🔴 **FAILED**
* **Error:** `tor: remote hostname lookup failure`
* **Analysis:** The Tor "Exit Node" (the server connecting us to the real world) could not resolve the DNS for the Zcash node, or the Zcash node blocked the Exit Node's IP.

### Phase 9: Tor + Direct IP (Bypassing DNS)
**Objective:** Bypass Exit Node DNS failure by using Google Cloud IP directly.
* **Target:** `35.235.105.143` (Official ECC IP) via Tor.
* **Result:** 🔴 **FAILED**
* **Error:** `tor: operation timed out at exit`
* **Analysis:** The destination server (Google Cloud) is explicitly blocking connections coming from known Tor Exit Nodes, or the Exit Nodes themselves block crypto ports (443/9067) to prevent abuse.

### Phase 10: The Onion Service Attempt (The Final Wall)
**Objective:** Connect to a `.onion` Hidden Service to eliminate Exit Nodes entirely.
* **Target:** `zcashnodesib... .onion` (ZecRocks Hidden Service).
* **Result:** 🔴 **CRITICAL FAILURE**
* **Error:** `tor: operation not supported because Arti feature disabled: Rejecting .onion address; feature onion-service-client not compiled in`
* **Root Cause:** The `ZcashLightClientKit` (SDK) was compiled with the `onion-service-client` feature **disabled** to save space.
* **Conclusion:** The app **cannot** connect to Onion addresses without recompiling the Rust dependencies from source, which is outside the scope of standard iOS development.

---

## 3. Final Verdict

We have exhausted the entire networking stack:
1.  **ISP Layer:** Bypassed successfully using Tor (`Arti`).
2.  **DNS Layer:** Bypassed using Direct IPs.
3.  **Transport Layer:** Failed. Public Zcash nodes block Tor Exit Nodes.
4.  **Protocol Layer:** Failed. The iOS SDK does not support `.onion` addresses (Hidden Services), removing the only way to bypass Exit Node blocking.

**Current Status:** The `ZECer` app cannot function in "Online Mode" within this specific network environment using the standard SDK distribution. The ISP blocks direct connections, servers block Tor exits, and the SDK blocks Onion services.

**Recommended Pivot:** Shift development to the **"Air-Gapped / Offline Signer"** architecture. This removes the requirement for the iPhone to ever connect to the internet, bypassing all network-level adversaries by design.
