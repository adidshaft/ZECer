//
//  NFCService.swift
//  ZECer
//
//  Created by Aman Pandey on 1/21/26.
//

import Foundation
import CoreBluetooth
import Combine

class BLEService: NSObject, ObservableObject {
    static let shared = BLEService()
    
    // MARK: - Configuration
    // A custom UUID for the ZECer Service
    private let serviceUUID = CBUUID(string: "A9279075-846D-44D6-9F7C-D3F2D4090123")
    // A custom UUID for the Data Transfer Characteristic
    private let characteristicUUID = CBUUID(string: "2A36384C-1521-4603-9092-23E4D6435052")
    
    // MARK: - Publishing State
    @Published var status: String = "Idle"
    @Published var progress: Double = 0.0
    @Published var isConnected = false
    
    // MARK: - Internal Bluetooth
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    
    private var transferCharacteristic: CBMutableCharacteristic?
    private var connectedPeripheral: CBPeripheral?
    
    // MARK: - Data Buffers
    private var outgoingData: Data?
    private var outgoingDataIndex: Int = 0
    private var incomingData = Data()
    
    // MTU (Maximum Transmission Unit) - Safe default
    private let notifyMTU = 182
    
    // MARK: - Init
    override init() {
        super.init()
        // Initialize both Central (Receiver) and Peripheral (Sender) roles
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public API
    
    func startReceiving() {
        incomingData.removeAll()
        progress = 0.0
        status = "Scanning..."
        
        if centralManager.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: [serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        }
    }
    
    func startSending(data: Data) {
        // Prepare data for sending
        outgoingData = data
        outgoingDataIndex = 0
        status = "Advertising..."
        
        if peripheralManager.state == .poweredOn {
            peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [serviceUUID]])
        }
    }
    
    func stop() {
        centralManager.stopScan()
        peripheralManager.stopAdvertising()
        status = "Idle"
        progress = 0.0
    }
}

// MARK: - Central Delegate (RECEIVER)
extension BLEService: CBCentralManagerDelegate, CBPeripheralDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("BLE Central Ready")
        } else {
            status = "Bluetooth Off"
        }
    }
    
    // 1. Found a Sender
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Accept strong signals only (security feature: requires proximity)
        if RSSI.intValue > -15 || RSSI.intValue < -90 { return }
        
        print("Discovered Sender: \(peripheral.name ?? "Unknown")")
        
        // Stop scanning to save battery and connect
        central.stopScan()
        status = "Connecting..."
        
        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        central.connect(peripheral, options: nil)
    }
    
    // 2. Connected
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        status = "Discovering..."
        peripheral.discoverServices([serviceUUID])
    }
    
    // 3. Services Found
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics([characteristicUUID], for: service)
        }
    }
    
    // 4. Characteristics Found -> SUBSCRIBE
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics where characteristic.uuid == characteristicUUID {
            peripheral.setNotifyValue(true, for: characteristic)
            status = "Receiving..."
        }
    }
    
    // 5. RECEIVE DATA CHUNKS
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        
        let stringFromData = String(data: data, encoding: .utf8)
        
        // Check for End of Message (EOM)
        if stringFromData == "EOM" {
            // FINISHED!
            finalizeReception()
            peripheral.setNotifyValue(false, for: characteristic)
            centralManager.cancelPeripheralConnection(peripheral)
        } else {
            // Append Chunk
            incomingData.append(data)
            
            // Visual feedback (fake progress for alpha)
            progress += 0.05
            if progress > 0.95 { progress = 0.95 }
        }
    }
    
    private func finalizeReception() {
        status = "Processing..."
        progress = 1.0
        
        print("Data Received: \(incomingData.count) bytes")
        
        // 1. Convert Data to String (Format: "SIGNATURE|||HEX")
        guard let fullString = String(data: incomingData, encoding: .utf8) else {
            print("Error: Could not decode received data")
            return
        }
        
        // 2. Parse (Simple split for Alpha)
        let components = fullString.components(separatedBy: "|||")
        
        var txHex = ""
        // If format matches, take the second part (Hex). If not, assume whole thing is Hex.
        if components.count > 1 {
            txHex = components.last ?? ""
        } else {
            txHex = fullString
        }
        
        // 3. SAVE TO DISK (Persistence)
        DispatchQueue.main.async {
            // We use dummy amount/memo because raw hex parsing is complex without the parser library
            TxManager.shared.saveIncoming(
                rawHex: txHex,
                amount: 0.05, // Placeholder for UI
                memo: "Offline Payment Received"
            )
            
            self.status = "Success!"
            
            // Reset after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.status = "Idle"
                self.progress = 0.0
            }
        }
    }
}

// MARK: - Peripheral Delegate (SENDER)
extension BLEService: CBPeripheralManagerDelegate {
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            print("BLE Peripheral Ready")
        }
    }
    
    // 1. Start Advertising
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("Advertising failed: \(error)")
            return
        }
        
        // Setup the Characteristic
        transferCharacteristic = CBMutableCharacteristic(
            type: characteristicUUID,
            properties: .notify,
            value: nil,
            permissions: .readable
        )
        
        let service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [transferCharacteristic!]
        
        peripheralManager.add(service)
    }
    
    // 2. Someone Subscribed -> START SENDING
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        print("Receiver subscribed. Sending data...")
        sendData()
    }
    
    // 3. Send Chunks
    private func sendData() {
        guard let transferCharacteristic = transferCharacteristic else { return }
        
        // Loop until the queue is full
        while true {
            
            // Check if we finished
            if outgoingDataIndex >= (outgoingData?.count ?? 0) {
                // Send EOM
                let eomSent = peripheralManager.updateValue(
                    "EOM".data(using: .utf8)!,
                    for: transferCharacteristic,
                    onSubscribedCentrals: nil
                )
                
                if eomSent {
                    // Reset
                    status = "Sent!"
                    print("Message Sent Completely.")
                    peripheralManager.stopAdvertising()
                }
                return
            }
            
            // Prepare Chunk
            guard let dataToSend = outgoingData else { return }
            
            // Calculate size
            var amountToSend = dataToSend.count - outgoingDataIndex
            if amountToSend > notifyMTU {
                amountToSend = notifyMTU
            }
            
            let chunk = dataToSend.subdata(in: outgoingDataIndex..<(outgoingDataIndex + amountToSend))
            
            // Attempt Send
            let didSend = peripheralManager.updateValue(
                chunk,
                for: transferCharacteristic,
                onSubscribedCentrals: nil
            )
            
            if !didSend {
                // Buffer full, wait for 'peripheralManagerIsReady'
                return
            }
            
            outgoingDataIndex += amountToSend
            
            // Update UI Progress
            let percentage = Double(outgoingDataIndex) / Double(dataToSend.count)
            DispatchQueue.main.async {
                self.progress = percentage
            }
        }
    }
    
    // 4. Buffer Cleared -> Continue Sending
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        sendData()
    }
}
