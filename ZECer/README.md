# 🛡️ ZECer: The Offline Cash Protocol

![Platform](https://img.shields.io/badge/Platform-iOS-black?logo=apple)
![Stack](https://img.shields.io/badge/Tech-SwiftUI_%7C_CoreBluetooth_%7C_ZcashSDK-orange)
![Status](https://img.shields.io/badge/Status-Alpha_Prototype-yellow)

> **"Digital cash should feel like physical cash."**

ZECer is a proof-of-concept iOS application that re-imagines **offline, peer-to-peer Zcash transactions**. It combines skeuomorphic design, physics-based gestures, and heavy haptics to restore the visceral feeling of handing value to another person—without needing an internet connection.

---

## 🌟 Core Features

* **The "Z-Check" Instrument:** A glowing, digital bearer instrument that replaces boring input fields.
* **Gesture-Based Economy:** Send funds by physically "flicking" the card up to a nearby device.
* **Acoustic & Haptic Reality:** Uses the Taptic Engine to simulate the friction of paper and the heavy "thud" of gold settling.
* **True Offline Transport:** Slices large crypto transactions into Bluetooth LE (BLE) packets to bypass the need for WiFi or Cellular.
* **Shielded by Default:** Built on `ZcashLightClientKit` (v2.4.2) to ensure financial privacy.

---

## 📊 Current Product State

We believe in radical transparency. ZECer is currently in **Alpha**, meaning the core "Magic" works, but the "Safety Belts" are still being installed.

| Component | Status | Maturity | Notes |
| :--- | :--- | :--- | :--- |
| **Core Wallet Engine** | 🟢 **Online** | **Alpha** | Fully capable of syncing with Mainnet, deriving keys, and generating valid zero-knowledge proofs. |
| **Offline Transport** | 🟢 **Online** | **Beta** | BLE packet fragmentation and reassembly is functional. "Fire-and-forget" protocol is fast but lacks retry logic. |
| **User Interface** | 🟢 **Polished** | **Release Candidate** | Physics animations, radar scanning, and haptics are production-grade. |
| **Data Persistence** | 🟠 **Pending** | **Prototype** | Received offline transactions are currently held in RAM. If the app closes before reconnecting to the internet, **data is lost.** |
| **Key Security** | 🔴 **Critical** | **Dev Mode** | Seed phrases are currently handled in the view layer for testing convenience. **Keychain storage is not yet active.** |

---

## 🔍 Transparency: Assumptions & Risks

We are building this in the open. If you are testing ZECer, you must understand the architectural assumptions we have made for this Alpha build:

### 1. The "Hot Wallet" Assumption
* **The State:** To prioritize the development of the BLE transport layer, we have not yet integrated the iOS Keychain enclave. The seed phrase is passed directly into the engine from the UI.
* **The Risk:** In this build, your seed phrase resides in the application memory. 
* **The Fix:** Production versions will implement `LocalAuthentication` (FaceID) to decrypt the seed from the Secure Enclave only when signing.

### 2. The "Happy Path" Network
* **The State:** The app assumes that once an offline packet is received, the receiver will eventually find the internet.
* **The Risk:** There is no local database (CoreData/Realm) caching the received blobs yet. If the app crashes or is force-closed after receiving money but *before* syncing, that transaction is gone.
* **The Fix:** We are building a persistent `OfflineTxStore` that survives app launches.

### 3. Mainnet Configuration
* **The State:** The code is currently pointed at **Zcash Mainnet** to prove real-world viability.
* **The Warning:** **DO NOT use this with your life savings.** While the cryptography is standard, the app's error handling is experimental. Use a wallet with <$5 worth of ZEC for testing.

---

## 🛠 Tech Stack

* **Language:** Swift 5
* **Framework:** SwiftUI + Combine
* **Cryptography:** Zcash SDK (v2.4.2)
* **Connectivity:** CoreBluetooth (Central & Peripheral Modes)
* **Feedback:** CoreHaptics

## 🚀 Getting Started

1.  **Clone the Repo:**
    ```bash
    git clone [https://github.com/yourusername/ZECer.git](https://github.com/yourusername/ZECer.git)
    ```
2.  **Dependencies:**
    Open `ZECer.xcodeproj` in Xcode 15+. Wait for Swift Package Manager to resolve `ZcashLightClientKit`.
3.  **Hardware Required:**
    You must use **two physical iPhones**. The BLE stack does not function on the iOS Simulator.
4.  **Sanitize:**
    Check `ContentView.swift`. Ensure you are not committing any real seed phrases in the `onAppear` block.

---

### 📜 License
MIT License. Built for the Cypherpunk future.
