//
//  EvisCrypt.swift
//  VendingIosSDK
//
//  Created on $(DATE).
//

import Foundation
import CommonCrypto

class EvisCrypt {
    private let key: [UInt8]
    
    enum CMACLength {
        case length16
        case length8
    }
    
    init(key: [UInt8]) {
        self.key = key
    }
    
    func aesDecrypt(key: [UInt8], iv: [UInt8], data: [UInt8]) -> [UInt8] {
        var myIV = iv
        
        // Truncate IV if longer than 16 bytes
        if myIV.count > 16 {
            let truncatedIV = Array(myIV.suffix(16))
            myIV = truncatedIV
        }
        
        // Ensure IV is exactly 16 bytes
        var finalIV = myIV
        if finalIV.count < 16 {
            finalIV = finalIV + [UInt8](repeating: 0, count: 16 - finalIV.count)
        } else if finalIV.count > 16 {
            finalIV = Array(finalIV.prefix(16))
        }
        
        // Ensure data is multiple of 16 bytes (padding mode is None in C#)
        var dataToDecrypt = data
        let remainder = dataToDecrypt.count % 16
        if remainder != 0 {
            let paddingNeeded = 16 - remainder
            dataToDecrypt = dataToDecrypt + [UInt8](repeating: 0, count: paddingNeeded)
        }
        
        var decrypted = [UInt8](repeating: 0, count: dataToDecrypt.count + kCCBlockSizeAES128)
        var numBytesDecrypted: size_t = 0
        
        let status = CCCrypt(
            CCOperation(kCCDecrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(0), // No padding (CBC mode)
            key,
            key.count,
            finalIV,
            dataToDecrypt,
            dataToDecrypt.count,
            &decrypted,
            decrypted.count,
            &numBytesDecrypted
        )
        
        guard status == kCCSuccess else {
            print("[VendingBLE] aesDecrypt: ERROR - CCCrypt failed with status: \(status)")
            return []
        }
        
        let result = Array(decrypted.prefix(Int(numBytesDecrypted)))
        return result
    }
    
    func aesEncrypt(key: [UInt8], iv: [UInt8], data: [UInt8]) -> [UInt8] {
        var myIV = iv
        
        // Truncate IV if longer than 16 bytes
        if myIV.count > 16 {
            let truncatedIV = Array(myIV.suffix(16))
            myIV = truncatedIV
        }
        
        // Ensure IV is exactly 16 bytes
        var finalIV = myIV
        if finalIV.count < 16 {
            finalIV = finalIV + [UInt8](repeating: 0, count: 16 - finalIV.count)
        } else if finalIV.count > 16 {
            finalIV = Array(finalIV.prefix(16))
        }
        
        // Ensure data is multiple of 16 bytes (padding mode is None in C#)
        var dataToEncrypt = data
        let remainder = dataToEncrypt.count % 16
        if remainder != 0 {
            let paddingNeeded = 16 - remainder
            dataToEncrypt = dataToEncrypt + [UInt8](repeating: 0, count: paddingNeeded)
        }
        
        var encrypted = [UInt8](repeating: 0, count: dataToEncrypt.count + kCCBlockSizeAES128)
        var numBytesEncrypted: size_t = 0
        
        let status = CCCrypt(
            CCOperation(kCCEncrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(0), // No padding (CBC mode)
            key,
            key.count,
            finalIV,
            dataToEncrypt,
            dataToEncrypt.count,
            &encrypted,
            encrypted.count,
            &numBytesEncrypted
        )
        
        guard status == kCCSuccess else {
            print("[VendingBLE] aesEncrypt: ERROR - CCCrypt failed with status: \(status)")
            return []
        }
        
        let result = Array(encrypted.prefix(Int(numBytesEncrypted)))
        return result
    }
    
    private func rol(_ b: [UInt8]) -> [UInt8] {
        var r = [UInt8](repeating: 0, count: b.count)
        var carry: UInt8 = 0
        
        for i in stride(from: b.count - 1, through: 0, by: -1) {
            let u = UInt16(b[i]) << 1
            r[i] = UInt8(u & 0xFF) + carry
            carry = UInt8((u & 0xFF00) >> 8)
        }
        
        return r
    }
    
    func aesCMAC(key: [UInt8], payload: [UInt8], cmacLength: CMACLength = .length16) -> [UInt8] {
        var data = payload
        
        // SubKey generation
        // step 1, AES-128 with key K is applied to an all-zero input block.
        let zeroBlock = [UInt8](repeating: 0, count: 16)
        let L = aesEncrypt(key: key, iv: zeroBlock, data: zeroBlock)
        
        // step 2, K1 is derived through the following operation:
        var firstSubkey = rol(L)
        if (L[0] & 0x80) == 0x80 {
            firstSubkey[15] ^= 0x87
        }
        
        // step 3, K2 is derived through the following operation:
        var secondSubkey = rol(firstSubkey)
        if (firstSubkey[0] & 0x80) == 0x80 {
            secondSubkey[15] ^= 0x87
        }
        
        // MAC computing
        if data.count != 0 && data.count % 16 == 0 {
            // If the size of the input message block is equal to a positive multiple of the block size (namely, 128 bits),
            // the last block shall be exclusive-OR'ed with K1 before processing
            for j in 0..<firstSubkey.count {
                data[data.count - 16 + j] ^= firstSubkey[j]
            }
        } else {
            // Otherwise, the last block shall be padded with 10^i
            var padding = [UInt8](repeating: 0, count: 16 - (data.count % 16))
            padding[0] = 0x80
            
            data.append(contentsOf: padding)
            
            // and exclusive-OR'ed with K2
            for j in 0..<secondSubkey.count {
                data[data.count - 16 + j] ^= secondSubkey[j]
            }
        }
        
        // The result of the previous process will be the input of the last encryption.
        let encResult = aesEncrypt(key: key, iv: zeroBlock, data: data)
        
        var hashValue = [UInt8](repeating: 0, count: 16)
        let startIndex = max(0, encResult.count - hashValue.count)
        hashValue = Array(encResult.suffix(16))
        
        // 8 Byte implementation
        if cmacLength == .length8 {
            // We are using just the first 8 Bytes
            return Array(hashValue.prefix(8))
        }
        
        return hashValue
    }
}

