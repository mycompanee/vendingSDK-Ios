//
//  StringObfuscator.swift
//  VendingIosSDK
//
//  String obfuscation utility for protecting sensitive strings
//

import Foundation

/// Utility class for obfuscating and deobfuscating strings at runtime
internal class StringObfuscator {
    
    /// Simple XOR-based obfuscation key
    private static let obfuscationKey: [UInt8] = [0x4D, 0x79, 0x43, 0x6F, 0x6D, 0x70, 0x61, 0x6E, 0x65, 0x65, 0x53, 0x44, 0x4B, 0x32, 0x30, 0x32, 0x34]
    
    /// Deobfuscates an obfuscated byte array to a string
    /// - Parameter obfuscatedBytes: The obfuscated byte array
    /// - Returns: The deobfuscated string
    static func deobfuscate(_ obfuscatedBytes: [UInt8]) -> String {
        var deobfuscated = [UInt8]()
        for (index, byte) in obfuscatedBytes.enumerated() {
            let keyByte = obfuscationKey[index % obfuscationKey.count]
            deobfuscated.append(byte ^ keyByte)
        }
        return String(bytes: deobfuscated, encoding: .utf8) ?? ""
    }
    
    /// Obfuscates a string to a byte array (for build-time generation)
    /// - Parameter string: The string to obfuscate
    /// - Returns: The obfuscated byte array
    static func obfuscate(_ string: String) -> [UInt8] {
        let bytes = Array(string.utf8)
        var obfuscated = [UInt8]()
        for (index, byte) in bytes.enumerated() {
            let keyByte = obfuscationKey[index % obfuscationKey.count]
            obfuscated.append(byte ^ keyByte)
        }
        return obfuscated
    }
}

/// Macro-like function for obfuscated strings
/// Usage: let url = OBFUSCATED([0x12, 0x34, 0x56, ...])
internal func OBFUSCATED(_ bytes: [UInt8]) -> String {
    return StringObfuscator.deobfuscate(bytes)
}

