# 🛡️ ZECer: The Offline Cash Protocol

![Platform](https://img.shields.io/badge/Platform-iOS-black?logo=apple)
![Stack](https://img.shields.io/badge/Tech-SwiftUI_%7C_CoreBluetooth_%7C_ZcashSDK-orange)
![Status](https://img.shields.io/badge/Status-Alpha_Prototype-yellow)

> **"Digital cash should feel like physical cash."**

ZECer is a proof-of-concept iOS application that re-imagines **offline, peer-to-peer Zcash transactions**. It combines skeuomorphic design, physics-based gestures, and heavy haptics to restore the visceral feeling of handing value to another person—without needing an internet connection.

---

## 🗺️ Roadmap to Production

We are building ZECer in distinct phases, moving from "Visual Prototype" to "Real-World Protocol."

| Phase | Name | Goal | Key Tech | Status |
| :--- | :--- | :--- | :--- | :--- |
| **1** | **Security & Onboarding** | Secure keys with hardware encryption. | `Keychain`, `LocalAuthentication` | ✅ **Completed** |
| **2** | **Persistence & Ledger** | Never lose data if the app crashes. | `CoreData`, `Combine` | ✅ **Completed** |
| **3** | **Real Crypto Engine** | Remove mocks. Generate real ZK-Proofs. | `ZcashLightClientKit`, `Testnet` | 🚧 **In Progress** |
| **4** | **Heavy Transport** | Send 4KB+ crypto payloads via BLE. | `CoreBluetooth`, Packet Chunking | 📅 Planned |
| **5** | **The Handshake** | Encrypt the BLE tunnel itself. | `CryptoKit`, `ECDH` Key Exchange | 📅 Planned |
| **6** | **Production Polish** | Compliance & App Store readiness. | Export Compliance, Error Handling | 📅 Planned |

---

## 🌟 Core Features

* **The "Z-Check" Interface:** A glowing, digital bearer instrument.
* **Gesture Sending:** Swipe up to "flick" cash to a nearby device.
* **Offline Activity Feed:** A local ledger that tracks your money before it hits the blockchain.
* **True Offline Transport:** Slices large crypto transactions into Bluetooth LE (BLE) packets.
* **Shielded by Default:** Built on `ZcashLightClientKit` (v2.4.2).

---

## 📊 Current Product State

ZECer is currently transitioning from **Alpha** (Mock) to **Beta** (Real Crypto).

| Component | Status | Maturity | Notes |
| :--- | :--- | :--- | :--- |
| **Core Wallet Engine** | 🟢 **Online** | **Alpha** | Syncs with Mainnet. Currently implementing "Offline Signing" flow. |
| **Offline Transport** | 🟢 **Working** | **Beta** | BLE chunking works for small payloads. Scaling for large ZK-proofs is next. |
| **User Interface** | 🟢 **Polished** | **Release Candidate** | Physics, haptics, and animations are production-grade. |
| **Data Persistence** | 🟢 **Active** | **Beta** | `TxManager` saves all transactions to CoreData. History persists across restarts. |
| **Key Security** | 🟢 **Secured** | **Beta** | Seed phrases are encrypted in the iOS Keychain and protected by FaceID. |

---

## 🔍 Transparency: Architectural Assumptions

We believe in radical transparency. If you are testing ZECer, understand these current architectural decisions:

### 1. The "Pending" State
* **The Logic:** Transactions sent offline are stored locally as "Pending."
* **The Reality:** The receiver acts as a "Mule." They carry the signed transaction blob until they find the internet, at which point they broadcast it to the Zcash network.
* **The Risk:** If the receiver's phone is destroyed before they sync, the transaction never happened.

### 2. Mainnet vs Testnet
* **Current Status:** The code is currently configured for **Zcash Mainnet** in the repo, but we are switching to **Testnet** for Phase 3 development to allow safe, cost-free testing of the broadcasting logic.
* **Warning:** Do not use with significant funds until Phase 6 is complete.

---

## 🛠 Tech Stack

* **Language:** Swift 5
* **Framework:** SwiftUI + Combine
* **Database:** Core Data
* **Cryptography:** Zcash SDK (v2.4.2)
* **Connectivity:** CoreBluetooth (Central & Peripheral Modes)

## 🚀 Getting Started

1.  **Clone the Repo:**
    ```bash
    git clone [https://github.com/adidshaft/ZECer.git](https://github.com/adidshaft/ZECer.git)
    ```
2.  **Dependencies:**
    Open `ZECer.xcodeproj` in Xcode 15+. Wait for Swift Package Manager to resolve `ZcashLightClientKit`.
3.  **Hardware Required:**
    Two physical iPhones are required to test the BLE transport layer.
4.  **Sanitize:**
    Check `ContentView.swift`. Ensure you are not committing any real seed phrases.

---

### 📜 License
MIT License. Built for the Cypherpunk future.
