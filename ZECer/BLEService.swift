//
//  NFCService.swift
//  ZECer
//
//  Created by Aman Pandey on 1/21/26.
//

import Foundation
import CoreBluetooth
import Combine

class BLEService: NSObject, ObservableObject, CBPeripheralManagerDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {

    // Unique IDs for our app
    let SERVICE_UUID = CBUUID(string: "A0B40192-3621-4F8B-933B-123456789012")
    let CHAR_UUID = CBUUID(string: "A0B40192-3621-4F8B-933B-123456789013")
    
    // Roles
    var peripheralManager: CBPeripheralManager?
    var centralManager: CBCentralManager?
    var connectedPeripheral: CBPeripheral?
    var transferCharacteristic: CBCharacteristic?
    
    // State
    @Published var status = "Idle"
    @Published var progress: Double = 0.0
    @Published var receivedTransactionData: Data?
    
    // Transfer Queues
    private var outgoingPackets: [TransferPacket] = []
    private var incomingPackets: [Int: Data] = [:] // Map: Index -> Data
    private var expectedTotalPackets = 0
    
    override init() {
        super.init()
    }
    
    // MARK: - SENDER (Peripheral Mode)
    func startSending(data: Data) {
        // 1. Slice the data
        self.outgoingPackets = Packetizer.chunk(data: data)
        self.status = "Advertising..."
        
        // 2. Start Bluetooth
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            let service = CBMutableService(type: SERVICE_UUID, primary: true)
            let characteristic = CBMutableCharacteristic(
                type: CHAR_UUID,
                properties: [.notify, .read],
                value: nil,
                permissions: [.readable]
            )
            service.characteristics = [characteristic]
            peripheral.add(service)
            peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [SERVICE_UUID]])
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        // Receiver connected! Start blasting packets.
        self.status = "Sending..."
        sendNextPacket(characteristic: characteristic)
    }
    
    func sendNextPacket(characteristic: CBCharacteristic) {
        // Simple "Fire and Forget" loop.
        // In production, you would wait for 'didUnroll' delegate to avoid queue filling.
        
        DispatchQueue.global(qos: .userInteractive).async {
            for packet in self.outgoingPackets {
                if let data = packet.toData() {
                    // Send packet
                    let didSend = self.peripheralManager?.updateValue(data, for: characteristic as! CBMutableCharacteristic, onSubscribedCentrals: nil)
                    
                    if didSend == false {
                        // Queue full? Wait a tiny bit (Hack for simplicity)
                        // Proper fix: Use peripheralManagerIsReadyToUpdateSubscribers
                        usleep(10000)
                    }
                    
                    DispatchQueue.main.async {
                        self.progress = Double(packet.id) / Double(self.outgoingPackets.count)
                    }
                }
            }
            DispatchQueue.main.async { self.status = "Sent!" }
        }
    }

    // MARK: - RECEIVER (Central Mode)
    func startReceiving() {
        self.status = "Scanning..."
        self.incomingPackets.removeAll()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: [SERVICE_UUID], options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Only connect if very close (Security through proximity)
        if RSSI.intValue > -60 {
            self.status = "Connecting..."
            self.connectedPeripheral = peripheral
            central.stopScan()
            central.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([SERVICE_UUID])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let services = peripheral.services {
            for service in services {
                peripheral.discoverCharacteristics([CHAR_UUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            for char in characteristics {
                if char.uuid == CHAR_UUID {
                    self.transferCharacteristic = char
                    peripheral.setNotifyValue(true, for: char) // Subscribe to stream
                    self.status = "Receiving..."
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value, let packet = TransferPacket.from(data: data) else { return }
        
        // Store packet
        incomingPackets[packet.id] = packet.payload
        expectedTotalPackets = packet.total
        
        // Update UI
        self.progress = Double(incomingPackets.count) / Double(packet.total)
        
        // Check if complete
        if incomingPackets.count == expectedTotalPackets {
            reassembleData()
        }
    }
    
    func reassembleData() {
        self.status = "Finalizing..."
        let sortedPackets = incomingPackets.sorted { $0.key < $1.key }
        var fullData = Data()
        for (_, payload) in sortedPackets {
            fullData.append(payload)
        }
        
        self.receivedTransactionData = fullData
        self.status = "Success!"
    }
}
