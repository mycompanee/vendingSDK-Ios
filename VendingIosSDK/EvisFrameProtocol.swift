//
//  EvisFrameProtocol.swift
//  VendingIosSDK
//
//  Created on $(DATE).
//

import Foundation

enum FPCommand: UInt8 {
    case unknown = 0x00
    case syncCrypt = 0x48
    case status = 0x55
}

struct FrameProtocolDetectedEventArgs {
    let detectedFrame: [UInt8]
    let decryptedPayload: [UInt8]?
    let encryptedPayload: [UInt8]?
    let commandByte: UInt8
    let command: FPCommand
    let byte1: UInt8
}

struct DecryptModel {
    var decryptedPayload: [UInt8]
    var encryptedPayload: [UInt8]
    var cmac: [UInt8]
}

class EvisFrameProtocol {
    var randomA: [UInt8]?
    var randomB: [UInt8]
    
    private var tempBuffer: [UInt8] = []
    private let crcCalc = Crc16Ccitt(initialValue: .zeros)
    private let evisCrypt: EvisCrypt
    
    var onFrameDetected: ((FrameProtocolDetectedEventArgs) -> Void)?
    
    init(evisCrypt: EvisCrypt) {
        self.evisCrypt = evisCrypt
        // Generate randomB for crypted communication
        randomB = (0..<16).map { _ in UInt8.random(in: 0...255) }
    }
    
    func getEmptyFrame(command: FPCommand, byte1: UInt8, payloadLength: Int) -> [UInt8] {
        var answer = [UInt8](repeating: 0, count: 8 + payloadLength)
        
        // Set SOF (Start of Frame)
        answer[0] = 0x11
        
        // Set EOF (End of Frame)
        answer[answer.count - 1] = 0x12
        
        // Set Command Byte
        answer[3] = command.rawValue
        
        // Set Byte1
        answer[4] = byte1
        
        return answer
    }
    
    func buildFrame(command: FPCommand, byte1: UInt8, payload: [UInt8]) -> [UInt8] {
        var answer = [UInt8](repeating: 0, count: 8 + payload.count)
        
        answer[0] = 0x11 // Set SOF (Start of Frame)
        answer[answer.count - 1] = 0x12 // Set EOF (End of Frame)
        answer[3] = command.rawValue // Set Command Byte
        answer[4] = byte1 // Set Byte1
        
        // Set Payload
        for i in 0..<payload.count {
            answer[5 + i] = payload[i]
        }
        
        return answer
    }
    
    func getCuttedFrame(_ frame: [UInt8]) -> [UInt8] {
        // Remove SOF & EOF and placeholder for crc bytes
        return Array(frame[1..<(frame.count - 3)])
    }
    
    func getCommandByte(_ frame: [UInt8]) -> UInt8 {
        return frame[3] // 4th byte is the command
    }
    
    func getRandomA(_ frame: [UInt8]) -> [UInt8] {
        // 16byte random from device
        var answer = [UInt8](repeating: 0, count: 16)
        for i in 0..<16 {
            if 5 + i < frame.count {
                answer[i] = frame[5 + i]
            }
        }
        return answer
    }
    
    func getByte1(_ frame: [UInt8]) -> UInt8 {
        return frame[4] // 5th byte is Byte 1
    }
    
    func parseCommandByte(_ commandByte: UInt8) -> FPCommand {
        switch commandByte {
        case 0x48:
            return .syncCrypt
        default:
            return .unknown
        }
    }
    
    func hasValidCRC(_ frame: [UInt8]) -> (Bool, String, String) {
        let crc = crcCalc.computeChecksumBytes(getCuttedFrame(frame))
        let messageCrc = String(format: "%02X-%02X", frame[frame.count - 3], frame[frame.count - 2])
        let calculatedCrc = String(format: "%02X-%02X", crc[0], crc[1])
        
        let isValid = messageCrc == calculatedCrc
        return (isValid, messageCrc, calculatedCrc)
    }
    
    func addCRCtoFrame(_ frame: [UInt8], endianness: Endianness = .littleEndian) -> [UInt8] {
        let crc = crcCalc.computeChecksumBytes(getCuttedFrame(frame), endianness: endianness)
        
        var answer = frame
        let crcStart = answer.count - 3
        
        // Insert 2 Byte CRC into Frame
        answer[crcStart] = crc[0] // First crc byte
        answer[crcStart + 1] = crc[1] // Second crc byte
        
        return answer
    }
    
    func removeCharacterStuffingFromFrame(_ frame: [UInt8]) -> [UInt8] {
        var buffer: [UInt8] = []
        
        buffer.append(frame[0])
        
        // SOF & EOF & CRC are not relevant!
        var i = 1
        while i < frame.count {
            // If we have a DLE we need to Translate the following Byte!
            if frame[i] == 0x10 && i + 1 < frame.count { // Data Link Escape for Character stuffing
                let stuffedByte = frame[i + 1]
                let translatedByte = stuffedByte ^ 0x80 // We need to XOR with 0x80!
                buffer.append(translatedByte)
                i += 2 // Skip the next byte
                continue
            }
            
            buffer.append(frame[i])
            i += 1
        }
        
        return buffer
    }
    
    func addCharacterStuffingToFrame(_ frame: [UInt8]) -> [UInt8] {
        var buffer: [UInt8] = []
        
        buffer.append(frame[0])
        
        for i in 1..<(frame.count - 1) {
            if frame[i] == 0x10 || frame[i] == 0x11 || frame[i] == 0x12 {
                let byteToStuff = frame[i]
                let translatedByte = byteToStuff ^ 0x80 // We need to XOR with 0x80!
                buffer.append(0x10) // Add the DLE (Data Link Escape) Character
                buffer.append(translatedByte)
                continue
            }
            
            buffer.append(frame[i])
        }
        
        buffer.append(frame[frame.count - 1])
        
        return buffer
    }
    
    func extractCMAC(_ encryptedFrame: [UInt8]) -> [UInt8] {
        var cmac = [UInt8](repeating: 0, count: 8)
        let startIndex = encryptedFrame.count - 11
        for i in 0..<8 {
            if startIndex + i < encryptedFrame.count {
                cmac[i] = encryptedFrame[startIndex + i]
            }
        }
        return cmac
    }
    
    func extractEncryptedPayload(_ encryptedFrame: [UInt8]) -> [UInt8] {
        var buffer: [UInt8] = []
        let endIndex = encryptedFrame.count - 11
        for i in 3..<endIndex {
            if i < encryptedFrame.count {
                buffer.append(encryptedFrame[i])
            }
        }
        return buffer
    }
    
    func decryptFrame(_ encryptedFrame: [UInt8], key: [UInt8], lastIV: [UInt8], evisCrypt: EvisCrypt) -> DecryptModel {
        let cmac = extractCMAC(encryptedFrame)
        let encryptedPayload = extractEncryptedPayload(encryptedFrame)
        let decryptedPayload = evisCrypt.aesDecrypt(key: key, iv: lastIV, data: encryptedPayload)
        
        return DecryptModel(
            decryptedPayload: decryptedPayload,
            encryptedPayload: encryptedPayload,
            cmac: cmac
        )
    }
    
    func detectFrame(_ data: [UInt8], key: [UInt8], lastIV: inout [UInt8], evisCrypt: EvisCrypt) {
        tempBuffer.append(contentsOf: data)
        
        // Find SOF and EOF
        var sofIndex = -1
        var eofIndex = -1
        
        for i in 0..<tempBuffer.count {
            if tempBuffer[i] == 0x11 && sofIndex == -1 {
                sofIndex = i
            }
            if tempBuffer[i] == 0x12 {
                eofIndex = i
                break
            }
        }
        
        // Extract the Frame
        if sofIndex >= 0 && eofIndex > sofIndex && tempBuffer.count > 0 {
            let frame = Array(tempBuffer[sofIndex...(eofIndex)])
            
            // Remove the character stuffing
            let unstuffed = removeCharacterStuffingFromFrame(frame)
            
            // Decrypt if encrypted
            var decrypted = DecryptModel(decryptedPayload: [], encryptedPayload: [], cmac: [])
            
            if unstuffed.count > 2 && unstuffed[2] == 0x01 {
                decrypted = decryptFrame(unstuffed, key: key, lastIV: lastIV, evisCrypt: evisCrypt)
                
                // Check CMAC (validation is done but not throwing error for now)
                let calculatedCMAC = evisCrypt.aesCMAC(key: key, payload: decrypted.decryptedPayload, cmacLength: .length8)
                let cmacMatch = calculatedCMAC == decrypted.cmac
                if !cmacMatch {
                    print("[VendingBLE] detectFrame: WARNING - CMAC mismatch!")
                }
                
                // Update lastIV with encrypted payload (this will be used as IV for next encryption)
                lastIV = decrypted.encryptedPayload
            }
            
            // Build Event
            // For encrypted frames, extract command from decrypted payload
            // For unencrypted frames, extract from raw frame
            let commandByte: UInt8
            let byte1: UInt8
            
            if !decrypted.decryptedPayload.isEmpty && decrypted.decryptedPayload.count > 2 {
                // Encrypted frame: command is in decrypted payload at index 1
                commandByte = decrypted.decryptedPayload[1]
                byte1 = decrypted.decryptedPayload.count > 2 ? decrypted.decryptedPayload[2] : 0
            } else {
                // Unencrypted frame: command is in raw frame
                commandByte = getCommandByte(frame)
                byte1 = getByte1(frame)
            }
            
            let command = parseCommandByte(commandByte)
            
            let event = FrameProtocolDetectedEventArgs(
                detectedFrame: unstuffed,
                decryptedPayload: decrypted.decryptedPayload.isEmpty ? nil : decrypted.decryptedPayload,
                encryptedPayload: decrypted.encryptedPayload.isEmpty ? nil : decrypted.encryptedPayload,
                commandByte: commandByte,
                command: command,
                byte1: byte1
            )
            
            // Clear buffer
            tempBuffer = []
            
            // Invoke Event
            onFrameDetected?(event)
        }
    }
}

