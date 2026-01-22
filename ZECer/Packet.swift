//
//  Packet.swift
//  ZECer
//
//  Created by Aman Pandey on 1/21/26.
//

import Foundation

struct TransferPacket: Codable, Identifiable {
    var id: Int              // Packet Sequence Number (0, 1, 2...)
    var total: Int           // Total packets expected (e.g., 50)
    var payload: Data        // The actual chunk of the Zcash transaction
    
    // Encodes this struct into raw bytes for Bluetooth
    func toData() -> Data? {
        try? JSONEncoder().encode(self)
    }
    
    // Decodes raw bytes back into the struct
    static func from(data: Data) -> TransferPacket? {
        try? JSONDecoder().decode(TransferPacket.self, from: data)
    }
}

// Helper to slice a big Zcash Tx into small packets
class Packetizer {
    // BLE MTU is often ~185 bytes safe limit. We use 150 to leave room for headers.
    static let chunkSize = 150
    
    static func chunk(data: Data) -> [TransferPacket] {
        var packets: [TransferPacket] = []
        let totalLength = data.count
        var offset = 0
        var id = 0
        
        // Calculate total packets needed
        let totalPackets = Int(ceil(Double(totalLength) / Double(chunkSize)))
        
        while offset < totalLength {
            let length = min(chunkSize, totalLength - offset)
            let range = offset..<(offset + length)
            let chunk = data.subdata(in: range)
            
            packets.append(TransferPacket(id: id, total: totalPackets, payload: chunk))
            
            offset += length
            id += 1
        }
        return packets
    }
}
