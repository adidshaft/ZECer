//
//  NetworkBroadcaster.swift
//  ZECer
//
//  Created by Aman Pandey on 1/21/26.
//

import Foundation

// MARK: - Errors

enum BroadcastError: LocalizedError {
    case invalidHex
    case allEndpointsFailed
    case serverRejected(code: Int32)

    var errorDescription: String? {
        switch self {
        case .invalidHex:
            return "Invalid transaction hex"
        case .allEndpointsFailed:
            return "All lightwalletd endpoints failed"
        case .serverRejected(let code):
            return "Server rejected transaction with code \(code)"
        }
    }
}

// MARK: - Broadcaster

class NetworkBroadcaster {
    static let shared = NetworkBroadcaster()

    private let endpoints: [(host: String, port: Int)] = [
        ("mainnet.lightwalletd.com", 443),  // ECC/ZF official
        ("lwd.nubis.cash",           443),  // Nighthawk
        ("mainnet.zec.rocks",        443)   // ZEC.rocks
    ]

    /// Submit a raw Zcash transaction to lightwalletd via manual gRPC-over-HTTP/2.
    func broadcast(rawTxHex: String) async throws {
        guard let rawBytes = Data(hexEncoded: rawTxHex) else {
            throw BroadcastError.invalidHex
        }

        // --- Build protobuf for RawTransaction { bytes data = 1; } ---
        // Field 1, wire type 2 (length-delimited) → tag byte 0x0A
        var protobuf = Data()
        protobuf.append(0x0A)
        protobuf.append(contentsOf: encodeVarint(UInt64(rawBytes.count)))
        protobuf.append(rawBytes)

        // --- Build gRPC frame: [0x00][4-byte BE msg length][protobuf] ---
        var grpcFrame = Data()
        grpcFrame.append(0x00)                          // compression flag: not compressed
        let msgLen = UInt32(protobuf.count)
        grpcFrame.append(UInt8((msgLen >> 24) & 0xFF))
        grpcFrame.append(UInt8((msgLen >> 16) & 0xFF))
        grpcFrame.append(UInt8((msgLen >>  8) & 0xFF))
        grpcFrame.append(UInt8( msgLen        & 0xFF))
        grpcFrame.append(protobuf)

        var lastError: Error = BroadcastError.allEndpointsFailed

        for endpoint in endpoints {
            let urlString = "https://\(endpoint.host):\(endpoint.port)/cash.z.wallet.sdk.rpc.CompactTxStreamer/SendTransaction"
            guard let url = URL(string: urlString) else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/grpc+proto", forHTTPHeaderField: "Content-Type")
            request.setValue("trailers",               forHTTPHeaderField: "TE")
            request.httpBody = grpcFrame
            request.timeoutInterval = 30

            do {
                let (responseData, _) = try await URLSession.shared.data(for: request)

                // Parse SendResponse { int32 errorCode = 1; }
                // Skip the 5-byte gRPC frame header before the protobuf payload
                guard responseData.count > 5 else {
                    print("⚠️  Empty response from \(endpoint.host)")
                    continue
                }
                let protoPayload = Data(responseData.dropFirst(5))
                let errorCode = parseErrorCode(from: protoPayload)

                if errorCode == 0 {
                    print("✅ Broadcast success via \(endpoint.host)")
                    return
                } else {
                    throw BroadcastError.serverRejected(code: errorCode)
                }
            } catch let e as BroadcastError {
                throw e             // server rejection is terminal — don't try other endpoints
            } catch {
                lastError = error
                print("Endpoint \(endpoint.host) failed: \(error)")
            }
        }

        throw lastError
    }

    // MARK: - Protobuf Helpers

    /// Decode field 1 (varint) from a minimal protobuf message.
    private func parseErrorCode(from data: Data) -> Int32 {
        var idx = data.startIndex
        while idx < data.endIndex {
            let tagByte = data[idx]
            idx = data.index(after: idx)
            let fieldNumber = Int(tagByte >> 3)
            let wireType   = Int(tagByte & 0x07)

            if fieldNumber == 1 && wireType == 0 {
                // Varint field — decode it
                var result: UInt64 = 0
                var shift = 0
                while idx < data.endIndex {
                    let b = data[idx]; idx = data.index(after: idx)
                    result |= UInt64(b & 0x7F) << shift
                    if b & 0x80 == 0 { break }
                    shift += 7
                }
                return Int32(bitPattern: UInt32(result & 0xFFFFFFFF))
            }

            // Skip unknown fields
            switch wireType {
            case 0: // varint
                while idx < data.endIndex {
                    let b = data[idx]; idx = data.index(after: idx)
                    if b & 0x80 == 0 { break }
                }
            case 2: // length-delimited
                var len: UInt64 = 0; var shift = 0
                while idx < data.endIndex {
                    let b = data[idx]; idx = data.index(after: idx)
                    len |= UInt64(b & 0x7F) << shift
                    if b & 0x80 == 0 { break }
                    shift += 7
                }
                idx = data.index(idx, offsetBy: Int(len), limitedBy: data.endIndex) ?? data.endIndex
            default:
                return 0  // unrecognised wire type — bail
            }
        }
        return 0
    }

    /// Encode a UInt64 as a protobuf base-128 varint.
    private func encodeVarint(_ value: UInt64) -> [UInt8] {
        var bytes = [UInt8]()
        var v = value
        while v > 0x7F {
            bytes.append(UInt8(v & 0x7F) | 0x80)
            v >>= 7
        }
        bytes.append(UInt8(v))
        return bytes
    }
}
