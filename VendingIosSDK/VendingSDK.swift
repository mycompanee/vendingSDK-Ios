//
//  VendingSDK.swift
//  VendingIosSDK
//
//  Created on $(DATE).
//

import Foundation

/// Delegate protocol for vending session callbacks (Objective-C compatible)
@objc public protocol VendingSDKDelegate: NSObjectProtocol {
    /// Called when the vending session status updates
    /// - Parameter status: Status message string
    @objc func vendingSDK(_ sdk: VendingSDK, didUpdateStatus status: String)
    
    /// Called when a vending transaction completes
    /// - Parameters:
    ///   - sdk: The VendingSDK instance
    ///   - result: The transaction result
    @objc func vendingSDK(_ sdk: VendingSDK, didCompleteTransaction result: VendingTransactionResult)
}

/// Main entry point for the VendingIosSDK
@objc public class VendingSDK: NSObject {
    
    /// Shared instance of the SDK
    @objc public static let shared = VendingSDK()
    
    private override init() {
        super.init()
    }
    
    /// Delegate for receiving vending session callbacks (Objective-C compatible)
    @objc public weak var delegate: VendingSDKDelegate?
    
    /// Get the current SDK version
    /// - Returns: The SDK version string (e.g., "1.0.0")
    @objc public static func getSDKVersion() -> String {
        return Config.sdkVersion
    }
    
    /// Abort the current vending session and gracefully close the connection
    /// This will disconnect from the BLE device and clean up all resources
    @objc public func abortVending() {
        let bleManager = VendingBLEManager.shared
        
        // Clear callbacks to prevent further updates
        bleManager.onStatusUpdate = nil
        bleManager.onTransactionComplete = nil
        
        // Gracefully disconnect from BLE device
        bleManager.disconnect()
    }
    
    /// Start vending workflow with authKey and vending machine number (Objective-C compatible)
    /// This method handles authentication, data loading, and BLE connection internally.
    /// Use the delegate property to receive status updates and transaction results.
    /// - Parameters:
    ///   - authKey: Authentication key
    ///   - apiKey: API key for third-party API access
    ///   - vendingMachineNumber: Machine number to connect to
    ///   - connectionTimeout: Timeout in seconds for BLE connection (default: 30 seconds)
    @objc public func startVending(
        authKey: String,
        apiKey: String,
        vendingMachineNumber: Int32,
        connectionTimeout: TimeInterval = 30.0
    ) {
        startVending(
            authKey: authKey,
            apiKey: apiKey,
            vendingMachineNumber: vendingMachineNumber,
            connectionTimeout: connectionTimeout,
            statusCallback: { [weak self] status in
                guard let self = self else { return }
                self.delegate?.vendingSDK(self, didUpdateStatus: status)
            },
            transactionCallback: { [weak self] result in
                guard let self = self else { return }
                self.delegate?.vendingSDK(self, didCompleteTransaction: result)
            }
        )
    }
    
    /// Start vending workflow with authKey and vending machine number (Swift closure-based API)
    /// This method handles authentication, data loading, and BLE connection internally.
    /// - Parameters:
    ///   - authKey: Authentication key
    ///   - apiKey: API key for third-party API access
    ///   - vendingMachineNumber: Machine number to connect to
    ///   - connectionTimeout: Timeout in seconds for BLE connection (default: 30 seconds)
    ///   - statusCallback: Callback for status messages (connecting, connected, sending saldo, etc.)
    ///   - transactionCallback: Callback for successful vending transaction with selection, price, etc.
    public func startVending(
        authKey: String,
        apiKey: String,
        vendingMachineNumber: Int32,
        connectionTimeout: TimeInterval = 30.0,
        statusCallback: @escaping (String) -> Void,
        transactionCallback: @escaping (VendingTransactionResult) -> Void
    ) {
        // Show SDK version at the start
        statusCallback("SDK Version: \(Config.sdkVersion)")
        
        // Step 1: Authenticate
        statusCallback("Authenticating...")
        login(authKey: authKey) { [weak self] token, error in
            guard let self = self else { return }
            
            if let error = error {
                statusCallback("Authentication failed: \(error.localizedDescription)")
                return
            }
            
            guard token != nil else {
                statusCallback("Authentication failed: No access token received")
                return
            }
            
            // Step 2: Get vending base data and purse information
            statusCallback("Loading vending data...")
            let group = DispatchGroup()
            var vendingBaseDataResult: Result<VendingBaseDataResponse, Error>?
            var locationsResult: Result<[GetLocationsWithPurseReponse], Error>?
            
            group.enter()
            self.getVendingBaseData { result in
                vendingBaseDataResult = result
                group.leave()
            }
            
            group.enter()
            self.getLocationsWithPurse { result in
                locationsResult = result
                group.leave()
            }
            
            group.notify(queue: .main) {
                guard let vendingBaseData = try? vendingBaseDataResult?.get() else {
                    statusCallback("Failed to load vending data")
                    return
                }
                
                // Step 3: Find vending machine
                guard let vendingMachine = vendingBaseData.vendingMachines?.first(where: { $0.machineNumber == vendingMachineNumber }) else {
                    statusCallback("Vending machine \(vendingMachineNumber) not found")
                    return
                }
                
                // Step 4: Get purse UUID from third-party API endpoint GET /Purse/Purse with apiKey
                // Then use that UUID to get full purse details from regular ClientService API (like C# app does)
                statusCallback("Loading purse information...")
                ClientServiceAPI.shared.getPurse(authKey: authKey, apiKey: apiKey) { [weak self] result in
                    guard let self = self else { return }
                    
                    switch result {
                    case .success(let purseFromThirdParty):
                        // Extract purseUUID from third-party API response
                        guard let purseUUID = purseFromThirdParty.uuid else {
                            statusCallback("Failed to get purse UUID from third-party API")
                            return
                        }
                        
                        // Step 5: Get full purse details from regular ClientService API using the UUID (like C# app)
                        statusCallback("Loading full purse details...")
                        ClientServiceAPI.shared.getPurseByUUID(purseUUID) { result in
                            switch result {
                            case .success(let fullPurseDetails):
                                // Step 6: Connect via BLE with full purse details
                                self.connectToVendingMachine(
                                    vendingMachine: vendingMachine,
                                    purse: fullPurseDetails,
                                    vendingBaseData: vendingBaseData,
                                    connectionTimeout: connectionTimeout,
                                    statusCallback: statusCallback,
                                    transactionCallback: transactionCallback
                                )
                            case .failure(let error):
                                statusCallback("Failed to load full purse details: \(error.localizedDescription)")
                            }
                        }
                    case .failure(let error):
                        statusCallback("Failed to load purse from third-party API: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func login(authKey: String, completion: @escaping (String?, Error?) -> Void) {
        AuthenticationService.shared.authenticate(authKey: authKey) { result in
            switch result {
            case .success(let token):
                completion(token, nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
    
    private func getVendingBaseData(completion: @escaping (Result<VendingBaseDataResponse, Error>) -> Void) {
        ClientServiceAPI.shared.getVendingBaseData(completion: completion)
    }
    
    private func getLocationsWithPurse(userId: String? = nil, completion: @escaping (Result<[GetLocationsWithPurseReponse], Error>) -> Void) {
        ClientServiceAPI.shared.getLocationsWithPurse(userId: userId, completion: completion)
    }
    
    private func connectToVendingMachine(
        vendingMachine: VendingMachine,
        purse: Purse,
        vendingBaseData: VendingBaseDataResponse,
        connectionTimeout: TimeInterval,
        statusCallback: @escaping (String) -> Void,
        transactionCallback: @escaping (VendingTransactionResult) -> Void
    ) {
        let bleManager = VendingBLEManager.shared
        
        // Setup callbacks
        bleManager.onStatusUpdate = statusCallback
        
        bleManager.onTransactionComplete = { [weak self] result in
            guard let self = self else { return }
            
            // Find article mapping
            var article: VendingArticle?
            if let mappings = vendingBaseData.vendingMachineArticleMappings {
                if let mapping = mappings.first(where: { $0.vendingMachineId == vendingMachine.id && $0.selection == result.selection }) {
                    article = vendingBaseData.vendingArticles?.first(where: { $0.id == mapping.vendingArticleId })
                } else if let fallbackMapping = mappings.first(where: { $0.vendingMachineId == vendingMachine.id && $0.selection == -1 }) {
                    article = vendingBaseData.vendingArticles?.first(where: { $0.id == fallbackMapping.vendingArticleId })
                }
            }
            
            // If no article found, create a default one
            if article == nil {
                article = VendingArticle(id: -99, plu: "-9999", name: "Unknown Article")
            }
            
            guard let finalArticle = article else {
                statusCallback("Transaction completed but article not found")
                return
            }
            
            // Create transaction in backend
            statusCallback("Creating transaction...")
            let request = VendingSendTransactionRequest(
                purseUUID: purse.uuid ?? "",
                machineNumber: vendingMachine.machineNumber,
                selection: result.selection,
                amount: result.amount,
                article: finalArticle,
                machine: vendingMachine,
                source: "iOS",
                costCenterId: nil
            )
            
            ClientServiceAPI.shared.sendVendingTransaction(request) { transactionResult in
                switch transactionResult {
                case .success(let response):
                    statusCallback("Transaction completed successfully")
                    let finalResult = VendingTransactionResult(
                        selection: result.selection,
                        amount: result.amount,
                        fingerprint: result.fingerprint,
                        articleStruct: finalArticle,
                        transactionResponseStruct: response
                    )
                    transactionCallback(finalResult)
                case .failure(let error):
                    statusCallback("Transaction failed: \(error.localizedDescription)")
                    // Still call callback with transaction result but without backend response
                    let finalResult = VendingTransactionResult(
                        selection: result.selection,
                        amount: result.amount,
                        fingerprint: result.fingerprint,
                        articleStruct: finalArticle,
                        transactionResponseStruct: nil
                    )
                    transactionCallback(finalResult)
                }
                
                // Disconnect after transaction
                bleManager.disconnect()
            }
        }
        
        // Connect to BLE device
        let connectionIdleTime = Int(vendingMachine.connectionIdleTimeout ?? 90)
        bleManager.connectToVendingMachine(
            deviceName: vendingMachine.evisBleIdentifier,
            communicationKey: vendingMachine.evisCommunicationKeyHexString,
            purse: purse,
            connectionIdleTime: connectionIdleTime,
            connectionTimeout: connectionTimeout
        )
    }
}

