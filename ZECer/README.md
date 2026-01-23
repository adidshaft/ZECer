# 🛡️ ZECer: Offline Shielded Cash 💸

![Platform](https://img.shields.io/badge/Platform-iOS-black?logo=apple)
![Stack](https://img.shields.io/badge/Tech-SwiftUI_%7C_CoreBluetooth_%7C_ZcashSDK-orange)
![Status](https://img.shields.io/badge/Status-Alpha_Prototype-yellow)

> **"Digital cash should feel like physical cash."**

**ZECer** is a proof-of-concept iOS application that enables **offline, peer-to-peer, privacy-preserving payments** using the Zcash protocol. It allows users to transact value physically—like handing over a $20 bill—without needing an active internet connection at the moment of trade.

---

## 🏗 Current Product State

ZECer is currently transitioning from a Testnet Simulation to a **Mainnet Alpha**. Below is the status of core capabilities:

| Feature Module | Status | Details |
| :--- | :---: | :--- |
| **Physical UI** | ✅ Ready | Skeuomorphic "Z-Bill" interface with drag-to-pay gestures. |
| **Security Core** | ✅ Ready | Biometric (FaceID) protection and Keychain-backed Seed Vault. |
| **Local Ledger** | ✅ Ready | CoreData persistence for offline history and state management. |
| **Network Engine** | 🔄 Migrating | Switching from Docker Testnet to **Zcash Mainnet**. |
| **Crypto Engine** | 🚧 In Progress | Implementing the "Cold Signer" to generate proofs without broadcasting. |
| **Transport** | 🚧 In Progress | Optimizing Bluetooth (BLE) for heavy 4KB+ crypto payloads. |

---

## 🛣️ Roadmap

We are currently executing **Phase 3**.

| Phase | Module | Goals & Deliverables | Status |
| :--- | :--- | :--- | :---: |
| **1** | **Foundation** | Secure the keys and build the physical user interface. <br>• *FaceID Auth, Seed Vault, Onboarding.* | ✅ Done |
| **2** | **Persistence** | Ensure money isn't lost if the app crashes. <br>• *Local Ledger, Activity Feed, Pending States.* | ✅ Done |
| **3** | **Integrity Core** | **(Current Focus)** Connect to Mainnet & enable Offline-Readiness. <br>• **Mainnet Switch:** Connect to official `lightwalletd` servers. <br>• **Shielding Bridge:** Auto-detect Transparent funds and provide "One-Tap Shielding" to make them usable offline. <br>• **Cold Signer:** Extract raw Hex Transaction blobs without broadcasting. | 🚧 In Progress |
| **4** | **Heavy Transport** | Move heavy crypto payloads (4KB - 10KB) reliably over thin air. <br>• **Packetizer:** Split Hex blobs into ~512-byte chunks. <br>• **Reassembler:** Logic to stitch chunks back into a valid Tx. | ⏳ Planned |
| **5** | **Privacy** | Prevent snooping on the Bluetooth layer. <br>• **ECDH Handshake:** Generate shared secrets between devices. <br>• **Transport Encrypt:** Encrypt packets before transmission. | ⏳ Planned |
| **6** | **Polish** | App Store Readiness. <br>• **Export Compliance:** Encryption documentation. <br>• **Safety Rails:** Backup warnings and error handling. | ⏳ Planned |

---

## 🔍 Transparency: The Offline Integrity Model

In a decentralized system without a central server to check balances, offline payments face the **Double Spending** problem (e.g., *If Alice is offline, what stops her from signing a transaction to Bob, and 5 minutes later signing the exact same funds to Charlie?*).

ZECer addresses this using **Maximum Practical Integrity** via the **"Mule" Protocol**.

### 1. The "Mule" Protocol (Receiver Custody)
We do not rely on the Sender to broadcast the transaction. instead, we enforce **Receiver Custody**.

* **The Transfer:** The Sender (Offline) generates a valid Zero-Knowledge Proof and signs the transaction. This heavy data blob (containing the unique **Nullifier**) is transferred via Bluetooth/NFC to the Receiver.
* **The Verification:** The Receiver's app locally validates the cryptographic proofs. It confirms: *"If this data reaches the internet, it is valid money."*
* **The "Mule":** The Receiver takes custody of the signed blob. They act as the "Mule," carrying the data until they regain internet connectivity to broadcast it.
* **Game Theory:** Since the Receiver wants to get paid, they have the financial incentive to upload the transaction immediately, claiming the Nullifier on the blockchain and invalidating any other attempts by the Sender to double-spend.

### 2. Hardware Limitations (Why not Secure Enclave?)
We explicitly **do not** use the iPhone Secure Enclave or Android TEE to enforce "counters" for double-spending prevention. This is due to two hard technical limitations:

* **Math Mismatch:** The Secure Enclave supports NIST P-256 curves. Zcash relies on **Jubjub** and **BLS12-381** curves. The hardware physically lacks the instructions to perform the required math.
* **The "Evil Twin" Attack:** Even if the hardware supported the math, a user could import the same Seed Phrase into two different devices. Device A would have no knowledge of Device B's state, allowing the user to sign conflicting transactions.

**Verdict:** We rely on **Cryptographic Proofs** for validity and **The Mule Protocol** for settlement integrity.

---

## 🏗️ Tech Stack

* **Language:** Swift 5 (SwiftUI)
* **Engine:** `ZcashLightClientKit` (Rust integration via FFI)
* **Consensus:** Zcash Mainnet (Sapling/Orchard Pools)
* **Database:** CoreData (Local Ledger) & SQLite (SDK Storage)
* **Connectivity:** `MultipeerConnectivity` (AirDrop-style discovery) & CoreBluetooth.

---

## 🚀 Setup & Installation (Mainnet Alpha)

**⚠️ WARNING: Real Money**
This branch is configured for **Zcash Mainnet**.
1.  The keys generated are **REAL**.
2.  Funds sent to this wallet are **REAL**.
3.  If you delete the app without backing up your seed phrase, **FUNDS ARE LOST FOREVER.**

### Prerequisites
* Xcode 15+
* Physical iPhone (Simulators struggle with FaceID and Camera)
* ~500MB free space (for Compact Block cache)

### Installation
1.  Clone the repo.
2.  Run `pod install` (if using CocoaPods) or let Swift Package Manager resolve dependencies.
3.  Verify `ZcashEngine.swift` is pointing to `mainnet.lightwalletd.com`.
4.  Build and Run on a physical device.

---

## 📄 License

MIT License. Open Source for the Zcash Community.
