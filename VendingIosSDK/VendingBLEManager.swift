//
//  VendingBLEManager.swift
//  VendingIosSDK
//
//  Created on $(DATE).
//

import Foundation
import CoreBluetooth
import os.log

struct VirtualRFIDCard {
    var uid: UInt32
    var balance: UInt32
    var maxBalance: UInt32
    var transactionCounter: UInt16
    var priceList: UInt8
    var userGroup: UInt8
}

class VendingBLEManager: NSObject {
    static let shared = VendingBLEManager()
    
    // Serial queue for thread-safe access to shared state
    private let bleQueue = DispatchQueue(label: "com.vending.ble.queue", qos: .userInitiated)
    
    // Logger for debugging
    private let logger = OSLog(subsystem: "com.vending.ble", category: "VendingBLEManager")
    
    private func log(_ message: String, type: OSLogType = .default) {
        os_log("%{public}@", log: logger, type: type, message)
        print("[VendingBLE] \(message)")
    }
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var readCharacteristic: CBCharacteristic?
    private var writeCharacteristic: CBCharacteristic?
    
    private let serviceUUID = CBUUID(string: "49535343-fe7d-4ae5-8fa9-9fafd205e455")
    private let readCharacteristicUUID = CBUUID(string: "49535343-1e4d-4bd9-ba61-23c647249616")
    private let writeCharacteristicUUID = CBUUID(string: "49535343-8841-43F4-A8D4-ECBE34729BB3")
    
    private var evisFrameProtocol: EvisFrameProtocol!
    private var evisCrypt: EvisCrypt!
    private var evisCommunicationKey: [UInt8] = []
    private var lastIV: [UInt8] = []
    private var pendingLastIV: [UInt8]? // Track new IV value to update after detectFrame completes
    
    private var appDataSent = false
    private var stopSending = false
    private var timerThreshold = 0
    private let detectConnectionLostThreshold = 200 // 20 seconds
    
    private var lastSelection: UInt16 = 0
    private var lastAmount: UInt32 = 0
    private var lastFingerprint: UInt32 = 0
    
    private var virtualCard = VirtualRFIDCard(
        uid: 0,
        balance: 0,
        maxBalance: UInt32.max,
        transactionCounter: 0,
        priceList: 0,
        userGroup: 0
    )
    
    private var connectionIdleTicks = 90
    private var connectionIdleTimer: Timer?
    private var checkConnectionTimer: Timer?
    
    var onStatusUpdate: ((String) -> Void)?
    var onTransactionComplete: ((VendingTransactionResult) -> Void)?
    
    private func updateStatus(_ message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.onStatusUpdate?(message)
        }
    }
    
    private var deviceName: String = ""
    private var isConnecting = false
    private var pendingConnection: (deviceName: String, communicationKey: String, purse: Purse, connectionIdleTime: Int, connectionTimeout: TimeInterval)?
    private var isBluetoothReady = false
    private var connectionTimeoutTimer: Timer?
    
    override init() {
        super.init()
        // Initialize with bleQueue so all delegate callbacks come on the same queue
        centralManager = CBCentralManager(delegate: self, queue: bleQueue)
    }
    
    func connectToVendingMachine(
        deviceName: String,
        communicationKey: String,
        purse: Purse,
        connectionIdleTime: Int = 90,
        connectionTimeout: TimeInterval = 30.0
    ) {
        // If Bluetooth state is unknown, wait for it to be determined
        if centralManager.state == .unknown {
            pendingConnection = (deviceName: deviceName, communicationKey: communicationKey, purse: purse, connectionIdleTime: connectionIdleTime, connectionTimeout: connectionTimeout)
            updateStatus("Initializing Bluetooth...")
            return
        }
        
        guard centralManager.state == .poweredOn else {
            updateStatus("Bluetooth is not powered on")
            return
        }
        
        // Proceed with connection
        performConnection(deviceName: deviceName, communicationKey: communicationKey, purse: purse, connectionIdleTime: connectionIdleTime, connectionTimeout: connectionTimeout)
    }
    
    private func performConnection(
        deviceName: String,
        communicationKey: String,
        purse: Purse,
        connectionIdleTime: Int,
        connectionTimeout: TimeInterval
    ) {
        updateStatus("Starting connection to \(deviceName)...")
        
        // Reset state for new connection
        stopSending = false
        appDataSent = false
        timerThreshold = 0
        
        self.deviceName = deviceName
        self.connectionIdleTicks = connectionIdleTime
        self.isConnecting = true
        
        // Start connection timeout timer (must run on main queue for UI updates)
        connectionTimeoutTimer?.invalidate()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connectionTimeoutTimer = Timer.scheduledTimer(withTimeInterval: connectionTimeout, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                // Execute timeout handling on bleQueue to ensure thread safety
                self.bleQueue.async {
                    if self.isConnecting && self.connectedPeripheral == nil {
                        // Timeout expired and no connection was established
                        self.centralManager.stopScan()
                        self.isConnecting = false
                        self.updateStatus("Connection timeout: Could not connect to device within \(Int(connectionTimeout)) seconds")
                        self.disconnect()
                    }
                }
            }
        }
        
        // Convert communication key
        let commKeySplitted = communicationKey.split(separator: "-")
        guard commKeySplitted.count == 16 else {
            updateStatus("Evis Communication Key wrong length! Expected 16, got \(commKeySplitted.count)")
            return
        }
        
        var evisCommKey: [UInt8] = []
        for part in commKeySplitted {
            if let byte = UInt8(part, radix: 16) {
                evisCommKey.append(byte)
            }
        }
        
        self.evisCommunicationKey = evisCommKey
        self.evisCrypt = EvisCrypt(key: evisCommKey)
        self.evisFrameProtocol = EvisFrameProtocol(evisCrypt: evisCrypt)
        
        // Setup virtual card
        let purseUUID = UUID(uuidString: purse.uuid ?? "") ?? UUID()
        virtualCard.uid = getCardUID(from: purseUUID)
        
        // Calculate balance based on credit limit (matches C# BLE.cs logic)
        let purseBalanceRaw = purse.balance ?? 0
        let purseBalance = Int64(purseBalanceRaw)
        let creditLimitRaw = purse.creditLimit ?? 0
        let creditLimit = Int64(creditLimitRaw)
        let calculatedBalance: Int64
        
        if creditLimit > 0 {
            // PostPay Mode: CreditLimit + Balance
            calculatedBalance = creditLimit + purseBalance
        } else {
            // Prepaid Mode: Just use Balance
            calculatedBalance = purseBalance
        }
        
        // Cap balance at 65000 and ensure it's non-negative
        var finalBalance = calculatedBalance
        if finalBalance > 65000 {
            finalBalance = 65000
        }
        if finalBalance < 0 {
            log("WARNING: Balance is negative (\(finalBalance)), clamping to 0", type: .error)
            finalBalance = 0
        }
        
        virtualCard.balance = UInt32(finalBalance)
        virtualCard.transactionCounter = UInt16(purse.transCounter ?? 0)
        virtualCard.userGroup = UInt8(purse.userGroupId ?? 0)
        virtualCard.priceList = UInt8(purse.priceListId ?? 0)
        
        log("Virtual card initialized - Balance: \(virtualCard.balance) cents, Mode: \(creditLimit > 0 ? "PostPay" : "Prepaid")")
        
        // Setup frame protocol handler - already on bleQueue since detectFrame is called from delegate callback
        evisFrameProtocol.onFrameDetected = { [weak self] event in
            self?.handleFrameDetected(event)
        }
        
        updateStatus("Connecting to vending machine...")
        
        // Start scanning (timeout is handled by connectionTimeoutTimer above)
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
    
    func disconnect() {
        stopSending = true
        appDataSent = false
        isConnecting = false
        timerThreshold = 0
        pendingConnection = nil
        
        checkConnectionTimer?.invalidate()
        checkConnectionTimer = nil
        connectionIdleTimer?.invalidate()
        connectionIdleTimer = nil
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        
        centralManager.stopScan()
        
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        
        connectedPeripheral = nil
        readCharacteristic = nil
        writeCharacteristic = nil
        
        updateStatus("Disconnected")
    }
    
    private func getCardUID(from uuid: UUID) -> UInt32 {
        // Convert UUID to bytes (16 bytes)
        let uuidString = uuid.uuidString.replacingOccurrences(of: "-", with: "")
        var bytes: [UInt8] = []
        
        var index = uuidString.startIndex
        while index < uuidString.endIndex {
            let nextIndex = uuidString.index(index, offsetBy: 2)
            if let byte = UInt8(uuidString[index..<nextIndex], radix: 16) {
                bytes.append(byte)
            }
            index = nextIndex
        }
        
        guard bytes.count >= 16 else {
            return 0
        }
        
        // Copy bytes 2-3 (indices 2-3) and bytes 14-15 (indices 14-15)
        var number: [UInt8] = []
        number.append(bytes[2])
        number.append(bytes[3])
        number.append(bytes[14])
        number.append(bytes[15])
        
        return UInt32(number[0]) << 24 | UInt32(number[1]) << 16 | UInt32(number[2]) << 8 | UInt32(number[3])
    }
    
    private func handleFrameDetected(_ event: FrameProtocolDetectedEventArgs) {
        timerThreshold = 0 // Reset connection timer
        
        guard let decryptedPayload = event.decryptedPayload else {
            // Handle sync frames
            if event.command == .syncCrypt && event.byte1 == 0x00 {
                log("Handling sync request")
                var toSend: [UInt8] = [0x11, 0x00, 0x00, 0x48, 0x00, 0x00, 0x00, 0x12]
                toSend = evisFrameProtocol.addCRCtoFrame(toSend)
                toSend = evisFrameProtocol.addCharacterStuffingToFrame(toSend)
                sendBytesRaw(toSend)
            } else if event.command == .syncCrypt && event.byte1 == 0x01 {
                // Handle sync key exchange
                handleSyncKeyExchange(event)
            }
            return
        }
        
        let command = decryptedPayload[1]
        let byte1 = decryptedPayload[2]
        let byte2 = decryptedPayload.count > 3 ? decryptedPayload[3] : 0
        
        // Note: lastIV will be updated after detectFrame completes to avoid simultaneous access
        // We'll use encryptedPayload from the event when needed for encryption
        
        // Poll (0x55)
        if command == 0x55 {
            // Update lastIV from received encrypted payload
            if let encryptedPayload = event.encryptedPayload {
                lastIV = encryptedPayload
            }
            
            var payload = [UInt8](repeating: 0, count: 16)
            payload[0] = 0x0c
            payload[1] = command
            payload[2] = 0x06  // Signal "App data ready"
            payload[3] = 0x00
            
            let encrypted = evisCrypt.aesEncrypt(key: evisCommunicationKey, iv: lastIV, data: payload)
            lastIV = encrypted
            pendingLastIV = encrypted
            let cmac = evisCrypt.aesCMAC(key: evisCommunicationKey, payload: payload, cmacLength: .length8)
            
            var answer: [UInt8] = [0x11, 0x00, 0x01]
            answer.append(contentsOf: encrypted)
            answer.append(contentsOf: cmac)
            answer.append(contentsOf: [0x00, 0x00, 0x12])
            
            var toSend = answer
            toSend = evisFrameProtocol.addCRCtoFrame(toSend)
            toSend = evisFrameProtocol.addCharacterStuffingToFrame(toSend)
            sendBytesRaw(toSend)
        }
        
        // GetAppData (0x67, 0x00)
        if command == 0x67 && byte1 == 0x00 {
            updateStatus("Sending balance to vending machine...")
            log("GetAppData request received - Sending balance: \(virtualCard.balance) cents")
            
            // Update lastIV from received encrypted payload
            if let encryptedPayload = event.encryptedPayload {
                lastIV = encryptedPayload
            } else {
                log("WARNING: No encrypted payload in event, using current lastIV", type: .error)
            }
            
            var payload = [UInt8](repeating: 0, count: 32)
            payload[0] = 0x0F
            payload[1] = command
            payload[2] = 0x00
            
            // Copy UID (big endian)
            let uidBytes = withUnsafeBytes(of: virtualCard.uid.bigEndian) { Array($0) }
            for i in 0..<4 {
                payload[3 + i] = uidBytes[i]
            }
            
            // Copy balance (3 bytes, big endian - skip first byte)
            let balanceBytes = withUnsafeBytes(of: virtualCard.balance.bigEndian) { Array($0) }
            payload[7] = balanceBytes[1]
            payload[8] = balanceBytes[2]
            payload[9] = balanceBytes[3]
            
            // Copy max balance (3 bytes, big endian - skip first byte)
            let maxBalanceBytes = withUnsafeBytes(of: virtualCard.maxBalance.bigEndian) { Array($0) }
            payload[10] = maxBalanceBytes[1]
            payload[11] = maxBalanceBytes[2]
            payload[12] = maxBalanceBytes[3]
            
            // Copy transaction counter (2 bytes, big endian)
            let transCounterBytes = withUnsafeBytes(of: virtualCard.transactionCounter.bigEndian) { Array($0) }
            payload[13] = transCounterBytes[0]
            payload[14] = transCounterBytes[1]
            
            // Copy price list and user group
            payload[15] = virtualCard.priceList
            payload[16] = virtualCard.userGroup
            
            if lastIV.count != 16 {
                log("WARNING: IV length is not 16 bytes!", type: .error)
            }
            
            let encrypted = evisCrypt.aesEncrypt(key: evisCommunicationKey, iv: lastIV, data: payload)
            lastIV = encrypted
            pendingLastIV = encrypted
            
            if encrypted.isEmpty {
                log("ERROR: Encryption returned empty array!", type: .error)
            }
            
            let cmac = evisCrypt.aesCMAC(key: evisCommunicationKey, payload: payload, cmacLength: .length8)
            if cmac.isEmpty {
                log("ERROR: CMAC calculation returned empty array!", type: .error)
            }
            
            var answer: [UInt8] = [0x11, 0x00, 0x01]
            answer.append(contentsOf: encrypted)
            answer.append(contentsOf: cmac)
            answer.append(contentsOf: [0x00, 0x00, 0x12])
            
            var toSend = answer
            toSend = evisFrameProtocol.addCRCtoFrame(toSend)
            toSend = evisFrameProtocol.addCharacterStuffingToFrame(toSend)
            sendBytesRaw(toSend)
            
            appDataSent = true
            connectedSuccessfully()
        }
        
        // WriteAppData (0x67, 0x01, 0x00) - Sale
        if command == 0x67 && byte1 == 0x01 && byte2 == 0x00 {
            var payload = [UInt8](repeating: 0, count: 16)
            payload[0] = 0x0a
            payload[1] = command
            payload[2] = 0x01
            payload[3] = decryptedPayload[4]
            payload[4] = decryptedPayload[5]
            payload[5] = decryptedPayload[6]
            
            // Use encryptedPayload from event as IV (avoid accessing lastIV while detectFrame has it)
            let currentIV = event.encryptedPayload ?? lastIV
            let encrypted = evisCrypt.aesEncrypt(key: evisCommunicationKey, iv: currentIV, data: payload)
            pendingLastIV = encrypted // Store for update after detectFrame completes
            let cmac = evisCrypt.aesCMAC(key: evisCommunicationKey, payload: payload, cmacLength: .length8)
            
            var answer: [UInt8] = [0x11, 0x00, 0x01]
            answer.append(contentsOf: encrypted)
            answer.append(contentsOf: cmac)
            answer.append(contentsOf: [0x00, 0x00, 0x12])
            
            var toSend = answer
            toSend = evisFrameProtocol.addCRCtoFrame(toSend)
            toSend = evisFrameProtocol.addCharacterStuffingToFrame(toSend)
            sendBytesRaw(toSend)
            
            // Extract amount (matches C#: Array.Copy(e.decryptedPayload, 4, tAmount, 1, 3); Array.Reverse(tAmount); BitConverter.ToUInt32)
            var tAmount: [UInt8] = [0, decryptedPayload[4], decryptedPayload[5], decryptedPayload[6]]
            tAmount.reverse()
            // Read as little-endian (BitConverter reads little-endian: byte[0] is LSB)
            lastAmount = UInt32(tAmount[0]) | (UInt32(tAmount[1]) << 8) | (UInt32(tAmount[2]) << 16) | (UInt32(tAmount[3]) << 24)
            
            // Extract selection (matches C#: Array.Copy(e.decryptedPayload, 7, tSelection, 0, 2); Array.Reverse(tSelection); BitConverter.ToUInt16)
            var tSelection: [UInt8] = [decryptedPayload[7], decryptedPayload[8]]
            tSelection.reverse()
            // Read as little-endian
            lastSelection = UInt16(tSelection[0]) | (UInt16(tSelection[1]) << 8)
            
            // Extract fingerprint (matches C#: Array.Copy(e.decryptedPayload, 9, tFingerprint, 0, 4); Array.Reverse(tFingerprint); BitConverter.ToUInt32)
            var tFingerprint: [UInt8] = Array(decryptedPayload[9..<13])
            tFingerprint.reverse()
            // Read as little-endian
            lastFingerprint = UInt32(tFingerprint[0]) | (UInt32(tFingerprint[1]) << 8) | (UInt32(tFingerprint[2]) << 16) | (UInt32(tFingerprint[3]) << 24)
            
            log("Transaction detected - Selection: \(lastSelection), Amount: \(lastAmount) cents, Fingerprint: \(lastFingerprint)")
            
            // Safely subtract amount to prevent arithmetic overflow
            if virtualCard.balance >= lastAmount {
                virtualCard.balance -= lastAmount
            } else {
                log("WARNING: Balance (\(virtualCard.balance)) is less than amount (\(lastAmount)), setting balance to 0", type: .error)
                virtualCard.balance = 0
            }
            appDataSent = false
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let result = VendingTransactionResult(
                    selection: Int32(self.lastSelection),
                    amount: Int32(self.lastAmount),
                    fingerprint: self.lastFingerprint,
                    articleStruct: nil, // Will be set by SDK
                    transactionResponseStruct: nil // Will be set by SDK
                )
                self.onTransactionComplete?(result)
            }
        }
        
        // WriteAppDataLaden (0x67, 0x01, 0x01 or 0x02) - Loading
        if command == 0x67 && byte1 == 0x01 && (byte2 == 0x01 || byte2 == 0x02) {
            var payload = [UInt8](repeating: 0, count: 16)
            payload[0] = 0x0a
            payload[1] = command
            payload[2] = 0x01
            payload[3] = decryptedPayload[4]
            payload[4] = decryptedPayload[5]
            payload[5] = decryptedPayload[6]
            
            // Use encryptedPayload from event as IV (avoid accessing lastIV while detectFrame has it)
            let currentIV = event.encryptedPayload ?? lastIV
            let encrypted = evisCrypt.aesEncrypt(key: evisCommunicationKey, iv: currentIV, data: payload)
            pendingLastIV = encrypted // Store for update after detectFrame completes
            let cmac = evisCrypt.aesCMAC(key: evisCommunicationKey, payload: payload, cmacLength: .length8)
            
            var answer: [UInt8] = [0x11, 0x00, 0x01]
            answer.append(contentsOf: encrypted)
            answer.append(contentsOf: cmac)
            answer.append(contentsOf: [0x00, 0x00, 0x12])
            
            var toSend = answer
            toSend = evisFrameProtocol.addCRCtoFrame(toSend)
            toSend = evisFrameProtocol.addCharacterStuffingToFrame(toSend)
            sendBytesRaw(toSend)
            
            // Extract amount (matches C#: Array.Copy(e.decryptedPayload, 4, tAmount, 1, 3); Array.Reverse(tAmount); BitConverter.ToUInt32)
            var tAmount: [UInt8] = [0, decryptedPayload[4], decryptedPayload[5], decryptedPayload[6]]
            tAmount.reverse()
            // Read as little-endian (BitConverter reads little-endian: byte[0] is LSB)
            lastAmount = UInt32(tAmount[0]) | (UInt32(tAmount[1]) << 8) | (UInt32(tAmount[2]) << 16) | (UInt32(tAmount[3]) << 24)
            
            // Extract selection (matches C#: Array.Copy(e.decryptedPayload, 7, tSelection, 0, 2); Array.Reverse(tSelection); BitConverter.ToUInt16)
            var tSelection: [UInt8] = [decryptedPayload[7], decryptedPayload[8]]
            tSelection.reverse()
            // Read as little-endian
            lastSelection = UInt16(tSelection[0]) | (UInt16(tSelection[1]) << 8)
            
            // Extract fingerprint (matches C#: Array.Copy(e.decryptedPayload, 9, tFingerprint, 0, 4); Array.Reverse(tFingerprint); BitConverter.ToUInt32)
            var tFingerprint: [UInt8] = Array(decryptedPayload[9..<13])
            tFingerprint.reverse()
            // Read as little-endian
            lastFingerprint = UInt32(tFingerprint[0]) | (UInt32(tFingerprint[1]) << 8) | (UInt32(tFingerprint[2]) << 16) | (UInt32(tFingerprint[3]) << 24)
            
            log("Loading detected - Selection: \(lastSelection), Amount: \(lastAmount) cents, Fingerprint: \(lastFingerprint)")
            
            virtualCard.balance += lastAmount
            appDataSent = false
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let result = VendingTransactionResult(
                    selection: Int32(self.lastSelection),
                    amount: -Int32(self.lastAmount), // Negative for loading
                    fingerprint: self.lastFingerprint,
                    articleStruct: nil,
                    transactionResponseStruct: nil
                )
                self.onTransactionComplete?(result)
            }
        }
        
        // ReleaseApp (0x56, 0x02)
        if command == 0x56 && byte1 == 0x02 {
            var payload = [UInt8](repeating: 0, count: 16)
            payload[0] = 0x0c
            payload[1] = command
            
            // Use encryptedPayload from event as IV (avoid accessing lastIV while detectFrame has it)
            let currentIV = event.encryptedPayload ?? lastIV
            let encrypted = evisCrypt.aesEncrypt(key: evisCommunicationKey, iv: currentIV, data: payload)
            pendingLastIV = encrypted // Store for update after detectFrame completes
            let cmac = evisCrypt.aesCMAC(key: evisCommunicationKey, payload: payload, cmacLength: .length8)
            
            var answer: [UInt8] = [0x11, 0x00, 0x01]
            answer.append(contentsOf: encrypted)
            answer.append(contentsOf: cmac)
            answer.append(contentsOf: [0x00, 0x00, 0x12])
            
            var toSend = answer
            toSend = evisFrameProtocol.addCRCtoFrame(toSend)
            toSend = evisFrameProtocol.addCharacterStuffingToFrame(toSend)
            sendBytesRaw(toSend)
            
            appDataSent = false
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let result = VendingTransactionResult(
                    selection: Int32(self.lastSelection),
                    amount: Int32(self.lastAmount),
                    fingerprint: self.lastFingerprint,
                    articleStruct: nil,
                    transactionResponseStruct: nil
                )
                self.onTransactionComplete?(result)
            }
        }
    }
    
    private func handleSyncKeyExchange(_ event: FrameProtocolDetectedEventArgs) {
        log("Handling sync key exchange")
        guard let detectedFrame = event.detectedPayload else {
            log("No detected frame payload", type: .error)
            return
        }
        
        // Get RandomA
        let randomA = evisFrameProtocol.getRandomA(detectedFrame)
        evisFrameProtocol.randomA = randomA
        
        // Build RandomBA
        var randomBA: [UInt8] = []
        randomBA.append(contentsOf: evisFrameProtocol.randomB)
        randomBA.append(contentsOf: randomA)
        
        let cmac = evisCrypt.aesCMAC(key: evisCommunicationKey, payload: randomBA, cmacLength: .length16)
        let cryptRandomA = evisCrypt.aesEncrypt(key: evisCommunicationKey, iv: cmac, data: randomA)
        
        pendingLastIV = cryptRandomA
        
        var payload: [UInt8] = []
        payload.append(contentsOf: evisFrameProtocol.randomB)
        payload.append(contentsOf: cryptRandomA)
        
        let toSend = evisFrameProtocol.buildFrame(command: .syncCrypt, byte1: 0x01, payload: payload)
        var toSendWithCRC = evisFrameProtocol.addCRCtoFrame(toSend)
        toSendWithCRC = evisFrameProtocol.addCharacterStuffingToFrame(toSendWithCRC)
        sendBytesRaw(toSendWithCRC)
    }
    
    private func connectedSuccessfully() {
        connectionIdleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.connectionIdleTicks <= 0 {
                self.disconnect()
            } else {
                self.connectionIdleTicks -= 1
            }
        }
        
        updateStatus("Connected")
    }
    
    private func sendBytesRaw(_ payload: [UInt8]) {
        if stopSending {
            log("Sending blocked - stopSending is true", type: .error)
            return
        }
        
        guard let characteristic = writeCharacteristic else {
            log("Cannot send - writeCharacteristic is nil", type: .error)
            return
        }
        
        guard let peripheral = connectedPeripheral else {
            log("Cannot send - connectedPeripheral is nil", type: .error)
            return
        }
        
        let data = Data(payload)
        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
    }
    
    private func startConnectionMonitoring() {
        checkConnectionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.timerThreshold += 1
            if self.timerThreshold >= self.detectConnectionLostThreshold {
                self.checkConnectionTimer?.invalidate()
                self.updateStatus("Connection lost")
                self.disconnect()
            }
        }
    }
}

extension VendingBLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothReady = (central.state == .poweredOn)
        
        if central.state == .poweredOn {
            // If there's a pending connection, proceed with it
            if let pending = pendingConnection {
                pendingConnection = nil
                performConnection(
                    deviceName: pending.deviceName,
                    communicationKey: pending.communicationKey,
                    purse: pending.purse,
                    connectionIdleTime: pending.connectionIdleTime,
                    connectionTimeout: pending.connectionTimeout
                )
            }
        } else if central.state != .unknown {
            // Bluetooth is not available (not unknown, but also not powered on)
            if isConnecting {
                updateStatus("Bluetooth is not available")
                isConnecting = false
            }
            // Clear pending connection if Bluetooth is not available
            if pendingConnection != nil {
                updateStatus("Bluetooth is not available")
                pendingConnection = nil
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name == deviceName && connectedPeripheral == nil {
            centralManager.stopScan()
            // Cancel connection timeout timer since we found the device
            connectionTimeoutTimer?.invalidate()
            connectionTimeoutTimer = nil
            connectedPeripheral = peripheral
            peripheral.delegate = self
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Cancel connection timeout timer since connection is established
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        isConnecting = false
        
        log("Device connected: \(peripheral.name ?? "Unknown")")
        updateStatus("Connected to device")
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionTimeoutTimer?.invalidate()
        connectionTimeoutTimer = nil
        updateStatus("Connection failed: \(error?.localizedDescription ?? "Unknown error")")
        isConnecting = false
        disconnect()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        updateStatus("Disconnected from device")
        isConnecting = false
    }
}

extension VendingBLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            log("Error discovering services: \(error.localizedDescription)", type: .error)
            return
        }
        
        guard let services = peripheral.services else {
            log("No services found", type: .error)
            return
        }
        
        log("Discovered \(services.count) service(s)")
        for service in services {
            if service.uuid == serviceUUID {
                log("Found matching service, discovering characteristics...")
                peripheral.discoverCharacteristics([readCharacteristicUUID, writeCharacteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            log("Error discovering characteristics: \(error.localizedDescription)", type: .error)
            return
        }
        
        guard let characteristics = service.characteristics else {
            log("No characteristics found", type: .error)
            return
        }
        
        log("Discovered \(characteristics.count) characteristic(s)")
        for characteristic in characteristics {
            if characteristic.uuid == readCharacteristicUUID {
                log("Found read characteristic, enabling notifications...")
                readCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == writeCharacteristicUUID {
                log("Found write characteristic")
                writeCharacteristic = characteristic
            }
        }
        
        if readCharacteristic != nil && writeCharacteristic != nil {
            log("Both characteristics ready, connection monitoring started")
            startConnectionMonitoring()
            // isConnecting is already set to false in didConnect
        } else {
            log("Missing characteristics - Read: \(readCharacteristic != nil), Write: \(writeCharacteristic != nil)", type: .error)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            log("Error receiving data: \(error.localizedDescription)", type: .error)
            return
        }
        
        guard let data = characteristic.value else {
            log("Received nil data from characteristic", type: .error)
            return
        }
        
        let bytes = [UInt8](data)
        
        // Already on bleQueue since CBCentralManager was initialized with it
        // Use a local variable to avoid simultaneous access issues with inout parameter
        var localLastIV = lastIV
        pendingLastIV = nil // Reset pending update
        evisFrameProtocol.detectFrame(bytes, key: evisCommunicationKey, lastIV: &localLastIV, evisCrypt: evisCrypt)
        // Update lastIV after detectFrame completes
        lastIV = localLastIV
        // Apply any pending IV update from handleFrameDetected (this takes precedence as it's the result of encryption)
        if let pending = pendingLastIV {
            lastIV = pending
            pendingLastIV = nil
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        // Notification state updated
    }
}

// Helper extension for FrameProtocolDetectedEventArgs
extension FrameProtocolDetectedEventArgs {
    var detectedPayload: [UInt8]? {
        return detectedFrame
    }
}

