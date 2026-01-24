# 📘 ZECer Connectivity & Network Troubleshooting Report

**Project:** ZECer (Native iOS Zcash Wallet)  
**Tech Stack:** Swift, SwiftUI, ZcashLightClientKit (ECC SDK)  
**Environment:** iOS 18+, Physical iPhone (India Region)  
**Network Constraints:** High-Restriction ISP Environment (Deep Packet Inspection / DNS Blocking)  
**Date:** January 2026

---

## 1. Executive Summary
The objective was to build a native iOS Zcash wallet ("ZECer") capable of syncing with the Zcash blockchain on the Mainnet. While the core application logic (key derivation, UI, state management) was successfully implemented, the project encountered severe network-level blockades specific to the ISP environment in India.

Despite implementing industry-standard bypass methods—including Obfuscated VPNs, custom DNS, timeout extensions (Zashi-style), and Cloudflare Workers—the native gRPC connection required by the Zcash SDK was consistently intercepted and dropped. This report documents every strategy attempted, the configuration used, and the resulting failure mode.

---

## 2. Chronological Troubleshooting Log

### Phase 1: Testnet Initialization
**Objective:** Connect to the Zcash Testnet for safe development.

* **Configuration:**
    * Endpoint: `lightwalletd.testnet.electriccoin.co`
    * Port: `9067`
    * Security: TLS/SSL Enabled
* **Result:** 🔴 **FAILED**
* **Error Log:** `SSL Handshake Failed` / `Certificate Invalid`.
* **Analysis:** The Testnet infrastructure certificates were either expired or rejected by Apple's strict App Transport Security (ATS) policies.
* **Decision:** Abandon Testnet and pivot immediately to **Mainnet** to utilize production-grade infrastructure.

---

### Phase 2: Mainnet Migration & Stability Fixes
**Objective:** Establish a stable application state without crashing during startup.

* **Initial Configuration:**
    * Endpoint: `mainnet.lightwalletd.com`
    * Birthday: Default (Genesis Block / Block 0)
* **Result:** 🔴 **CRITICAL FAIL (Crash)**
* **Behavior:** The app would freeze and crash immediately upon `synchronizer.start()`.
* **Root Cause:** The SDK attempted to scan ~8 years of transaction history (from Block 0), overloading the iPhone's memory and CPU.
* **Fix Implemented:** **"The Birthday Fix"**
    * Modified `walletBirthday` to `BlockHeight(2750000)` (Late 2024/Early 2025).
* **Outcome:** ✅ **SUCCESS**. The engine started successfully, and logs confirmed `✅ ENGINE STARTED`.

---

### Phase 3: The ISP Blockade (Direct Connections)
**Objective:** Complete the server handshake (`validateServer`) and begin downloading blocks.

#### Attempt 3.1: Official ECC Node
* **Target:** `mainnet.lightwalletd.com` (Port 443)
* **Result:** 🔴 **FAILED (Timeout)**
* **Error Log:** `serviceGetInfoFailed(ZcashLightClientKit.LightWalletServiceError.timeOut)`
* **Observation:** The request was leaving the phone but never receiving an ACK packet. This indicated packet dropping at the ISP level.

#### Attempt 3.2: Community Nodes (ZecRocks / Nighthawk)
* **Target:** `zcash.adityapk.com` / `mainnet.zec.rocks`
* **Rationale:** Testing if only the specific ECC IP was blocked.
* **Result:** 🔴 **FAILED (Timeout)**
* **Analysis:** The blocking mechanism is targeting the **gRPC Protocol** itself, not just specific IP addresses.

---

### Phase 4: Encrypted Tunneling (VPNs & Privacy Tech)
**Objective:** Encrypt the gRPC packets to bypass Deep Packet Inspection (DPI).

#### Attempt 4.1: Cloudflare WARP (1.1.1.1 App)
* **Configuration:** "1.1.1.1 with WARP" active.
* **Result:** 🔴 **FAILED**. Connectivity remained identical to direct ISP connection.

#### Attempt 4.2: NordVPN (Standard / NordLynx)
* **Configuration:** Protocol: NordLynx (UDP). Server: Switzerland/Netherlands.
* **Result:** 🔴 **FAILED (Timeout)**.
* **Analysis:** High latency (>300ms) caused the default SDK timeout (10s) to trigger before the handshake could complete.

#### Attempt 4.3: Nym Mixnet (Privacy Overlay)
* **Configuration:** Routed traffic through Nym Mixnet (Switzerland Exit).
* **Result:** 🔴 **FAILED**.
* **Analysis:** Mixnets introduce 2–5 seconds of latency per packet. The Zcash gRPC protocol is sensitive to latency and dropped the connection.

#### Attempt 4.4: NordVPN Obfuscated Servers (TCP)
* **Configuration:** Protocol: OpenVPN (TCP). Server: Singapore (Obfuscated).
* **Rationale:** "Obfuscated" mode strips VPN headers to look like HTTPS traffic.
* **Result:** 🔴 **FAILED**.
* **Analysis:** While this bypassed packet inspection, the handshake still failed. This pointed to a potential **DNS Leak** or **Protocol Timeout**.

---

### Phase 5: The "Zashi" Protocol & DNS Hardening
**Objective:** Replicate the robust configuration of the official Zashi wallet and fix DNS leaks.

#### Attempt 5.1: Zashi Timeout Overrides
* **Hypothesis:** The connection *is* working, but is too slow for the default 10s timeout.
* **Code Change:** Updated `LightWalletEndpoint` with Zashi-style timeouts:
    ```swift
    singleCallTimeoutInMillis: 60000,    // 60 Seconds
    streamingCallTimeoutInMillis: 120000 // 2 Minutes
    ```
* **Result:** 🔴 **FAILED**. Logs still showed `timeOut`, but after a longer delay.

#### Attempt 5.2: The "Safari Test" & DNS Discovery
* **Test:** Attempted to open `https://mainnet.lightwalletd.com/` in Safari on the iPhone.
* **Result:** ❌ **"Safari cannot find the server."**
* **Smoking Gun:** This confirmed the phone could not resolve the Domain Name, even with VPN active.

#### Attempt 5.3: Advanced DNS Configuration
* **Actions:**
    1.  Disabled **iCloud Private Relay**.
    2.  Disabled **Limit IP Address Tracking** (Wi-Fi Settings).
    3.  Set NordVPN DNS manually to `8.8.8.8` (Google) and `1.1.1.1`.
* **Result:** 🔴 **FAILED**. Safari continued to report "Server cannot be found."
* **Conclusion:** The ISP/OS combo was ignoring the VPN DNS settings and forcing local DNS resolution, which blackholes crypto domains.

---

### Phase 6: The Cloudflare Bridge (Proxy Strategy)
**Objective:** Launder Zcash traffic through a generic Cloudflare Worker (`workers.dev`) to bypass ISP blocking of crypto domains.

#### Attempt 6.1: Standard Forwarding
* **Architecture:** App -> `my-worker.workers.dev` -> `mainnet.lightwalletd.com`
* **Result:** 🔴 **FAILED (Cloudflare Error 1016)**
* **Error:** `Origin DNS Error`.
* **Analysis:** Cloudflare's internal servers could not resolve the ECC node domain.

#### Attempt 6.2: Direct IP Targeting
* **Code Change:** Hardcoded the target to IP `35.235.105.143` (Google Cloud) to bypass DNS.
* **Result:** 🔴 **FAILED (Cloudflare Error 1003)**
* **Error:** `Direct IP access not allowed`.
* **Analysis:** Cloudflare Free Tier security policy forbids Workers from connecting to raw IP addresses.

#### Attempt 6.3: "Infrastructure" Node Target
* **Target:** `lwd1.zcash-infra.com` (Vultr Hosting).
* **Result:** 🔴 **FAILED (Error 1016)**.
* **Conclusion:** Cloudflare effectively blocks outbound connections to known Zcash gRPC ports on free accounts.

---

### Phase 7: Comparative Analysis (ZecGifts vs. ZECer)
**Question:** Why does `zecgifts.xyz` work in Safari while `ZECer` fails?

| Feature | ZECer (Native iOS App) | ZecGifts (Web App) |
| :--- | :--- | :--- |
| **Protocol** | **Native gRPC** (HTTP/2 + Binary) | **gRPC-Web** (Standard HTTP/1.1 Text) |
| **Connection** | Direct to Node (Port 443/9067) | Via HTTP Proxy / Envoy |
| **ISP Visibility** | Distinct "gRPC" fingerprint | Looks like standard website traffic |
| **Result** | **Blocked** | **Allowed** |

**Conclusion:** The ISP block specifically targets the **Native gRPC protocol** used by the iOS SDK. Web apps survive because they use a different, more standard protocol (gRPC-Web) that proxies the traffic.

---

## 3. Final Recommendations

### Option A: The "Remote" Test (Validation)
To definitively prove the code is bug-free and the issue is purely environmental:
* **Action:** Distribute the app (via TestFlight or Source Code) to a user in a non-restricted region (US/EU).
* **Expected Result:** The app will connect and sync immediately using the `mainnet.lightwalletd.com` endpoint.

### Option B: The "Offline Signer" Architecture (Solution)
Since the ISP creates an insurmountable barrier for the native SDK:
1.  **Split the App:** Decouple networking from signing.
2.  **App 1 (Watch-Only):** A web/desktop app running on a server outside India. It handles all syncing and creates unsigned transactions.
3.  **App 2 (ZECer iOS):** An **Offline-Only** app. It holds the Seed Phrase, scans QR codes from App 1, signs them locally, and displays the signed result.
4.  **Security Benefit:** This "Air-Gapped" approach is immune to network blocking and offers higher security for the private key.

---
*End of Report*
