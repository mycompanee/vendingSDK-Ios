//
//  Crc16Ccitt.swift
//  VendingIosSDK
//
//  Created on $(DATE).
//

import Foundation

enum InitialCrcValue: UInt16 {
    case zeros = 0x0000
    case nonZero1 = 0xFFFF
    case nonZero2 = 0x1D0F
}

enum Endianness {
    case bigEndian
    case littleEndian
}

class Crc16Ccitt {
    private let poly: UInt16 = 4129
    private var table: [UInt16] = Array(repeating: 0, count: 256)
    private let initialValue: UInt16
    
    init(initialValue: InitialCrcValue) {
        self.initialValue = initialValue.rawValue
        
        for i in 0..<table.count {
            var temp: UInt16 = 0
            var a = UInt16(i) << 8
            
            for _ in 0..<8 {
                if ((temp ^ a) & 0x8000) != 0 {
                    temp = (temp << 1) ^ poly
                } else {
                    temp <<= 1
                }
                a <<= 1
            }
            
            table[i] = temp
        }
    }
    
    private func computeChecksum(_ bytes: [UInt8]) -> UInt16 {
        var crc = initialValue
        
        for byte in bytes {
            crc = (crc << 8) ^ table[Int((crc >> 8) ^ UInt16(byte & 0xFF))]
        }
        
        return crc
    }
    
    func computeChecksumBytes(_ bytes: [UInt8], endianness: Endianness = .littleEndian) -> [UInt8] {
        let crc = computeChecksum(bytes)
        let crcBytes = withUnsafeBytes(of: crc) { Array($0) }
        
        if endianness == .littleEndian {
            return [crcBytes[1], crcBytes[0]]
        } else {
            return [crcBytes[0], crcBytes[1]]
        }
    }
}

