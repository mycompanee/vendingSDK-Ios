//
//  Models.swift
//  VendingIosSDK
//
//  Created on $(DATE).
//

import Foundation

// MARK: - VendingBaseDataResponse

public struct VendingBaseDataResponse: Codable {
    public let vendingMachines: [VendingMachine]?
    public let vendingArticles: [VendingArticle]?
    public let vendingMachineArticleMappings: [VendingMachineArticleMapping]?
    public let vendingMachinePriceMappings: [VendingMachinePriceMapping]?
    public let costCenters: [CostCenter]?
    
    enum CodingKeys: String, CodingKey {
        case vendingMachines
        case vendingArticles
        case vendingMachineArticleMappings
        case vendingMachinePriceMappings
        case costCenters
    }
}

// MARK: - VendingMachine

public struct VendingMachine: Codable {
    public let id: Int64
    public let locationId: Int64
    public let machineNumber: Int32
    public let invoiceCounter: Int64
    public let evisBleIdentifier: String
    public let bleMacAddress: String?
    public let evisCommunicationKeyHexString: String
    public let machineName: String?
    public let building: String?
    public let forceVendingSaldo: Int32?
    public let connectionIdleTimeout: Int32?
    public let evisSerial: Int64?
    public let externalMachineNumber: Int64?
    public let vendingExportTargetId: Int64?
    
    enum CodingKeys: String, CodingKey {
        case id
        case locationId
        case machineNumber
        case invoiceCounter
        case evisBleIdentifier
        case bleMacAddress
        case evisCommunicationKeyHexString
        case machineName
        case building
        case forceVendingSaldo
        case connectionIdleTimeout
        case evisSerial
        case externalMachineNumber
        case vendingExportTargetId
    }
}

// MARK: - VendingArticle

public struct VendingArticle: Codable {
    public let id: Int64
    public let plu: String
    public let name: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case plu
        case name
    }
}

/// Objective-C compatible wrapper for VendingArticle
@objc public class VendingArticleObjC: NSObject {
    @objc public let id: Int64
    @objc public let plu: String
    @objc public let name: String
    
    @objc public init(id: Int64, plu: String, name: String) {
        self.id = id
        self.plu = plu
        self.name = name
        super.init()
    }
    
    convenience init(from article: VendingArticle) {
        self.init(id: article.id, plu: article.plu, name: article.name)
    }
}

// MARK: - VendingMachineArticleMapping

public struct VendingMachineArticleMapping: Codable {
    public let id: Int64
    public let vendingMachineId: Int64
    public let selection: Int32
    public let vendingArticleId: Int64
    
    enum CodingKeys: String, CodingKey {
        case id
        case vendingMachineId
        case selection
        case vendingArticleId
    }
}

// MARK: - VendingMachinePriceMapping

public struct VendingMachinePriceMapping: Codable {
    public let id: Int64
    public let vendingMachineId: Int64
    public let vendingArticleId: Int64
    public let userGroupId: Int64?
    public let subuserGroupId: Int64?
    public let priceListId: Int64?
    public let articlePrice: Int32
    
    enum CodingKeys: String, CodingKey {
        case id
        case vendingMachineId
        case vendingArticleId
        case userGroupId
        case subuserGroupId
        case priceListId
        case articlePrice
    }
}

// MARK: - CostCenter

public struct CostCenter: Codable {
    public let id: Int64
    public let locked: Bool
    public let lockReason: String?
    public let identifier: String?
    public let company: String?
    public let name: String?
    public let street: String?
    public let postCode: String?
    public let city: String?
    public let email: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case locked
        case lockReason
        case identifier
        case company
        case name
        case street
        case postCode
        case city
        case email
    }
}

// MARK: - TokenResponse

struct TokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int
    let tokenType: String
    let refreshToken: String?
    let scope: String?
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case refreshToken = "refresh_token"
        case scope
    }
}

// MARK: - TokenErrorResponse

struct TokenErrorResponse: Codable {
    let error: String
    let errorDescription: String?
    
    enum CodingKeys: String, CodingKey {
        case error
        case errorDescription = "error_description"
    }
}

// MARK: - Location

public struct Location: Codable {
    public let id: Int64
    public let uuid: String
    public let currencyId: Int64
    public let createdAt: String
    public let name: String
    public let description: String?
    public let allowLoading: Bool
    public let allowedLoadingValues: String?
    public let maxLoadingValue: Int64
    public let appLayoutId: Int64
    public let webLayoutId: Int64
    public let managerEmail: String?
    public let managerFirstName: String?
    public let managerLastName: String?
    public let managerPhone: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case uuid
        case currencyId
        case createdAt
        case name
        case description
        case allowLoading
        case allowedLoadingValues
        case maxLoadingValue
        case appLayoutId
        case webLayoutId
        case managerEmail
        case managerFirstName
        case managerLastName
        case managerPhone
    }
}

// MARK: - GetLocationsWithPurseReponse

public struct GetLocationsWithPurseReponse: Codable {
    public let location: Location
    public let purse: Purse?
    
    enum CodingKeys: String, CodingKey {
        case location
        case purse
    }
}

// MARK: - ThirdPartyPurseResponse (wrapper from /Purse/Purse endpoint)

/// Response wrapper from third-party API GET /Purse/Purse endpoint
public struct ThirdPartyPurseResponse: Codable {
    public let auth: ThirdPartyAuth?
    public let newAccessToken: String?
    public let purse: Purse
    public let location: Location?
    public let rfid_Cards: [PurseExtCardNumber]?
    
    enum CodingKeys: String, CodingKey {
        case auth
        case newAccessToken
        case purse
        case location
        case rfid_Cards = "rfid_Cards"
    }
}

// MARK: - ThirdPartyAuth

public struct ThirdPartyAuth: Codable {
    public let userId: String
    public let tenantId: Int32
    public let tokenExpiration: String
    public let requestDuration: String?
}

// MARK: - PurseExtCardNumber

public struct PurseExtCardNumber: Codable {
    public let id: Int64?
    public let purseId: Int64?
    public let locationId: Int64?
    public let cardNumber: String?
    public let description: String?
}

// MARK: - Purse

public struct Purse: Codable {
    public let id: Int64?
    public let uuid: String?
    public let userId: String?
    public let locationId: Int64?
    public let balance: Int64?
    public let currencyId: Int64?
    public let creditLimit: Int64?
    public let userGroupId: Int64?
    public let priceListId: Int64?
    public let transCounter: Int32?
    
    enum CodingKeys: String, CodingKey {
        case id
        case uuid
        case userId
        case locationId
        case balance
        case currencyId
        case creditLimit
        case userGroupId
        case priceListId
        case transCounter
    }
}

// MARK: - VendingSendTransactionRequest

public struct VendingSendTransactionRequest: Codable {
    public let purseUUID: String
    public let machineNumber: Int32
    public let selection: Int32
    public let amount: Int32
    public let article: VendingArticle
    public let machine: VendingMachine
    public let source: String
    public let costCenterId: Int64?
    
    enum CodingKeys: String, CodingKey {
        case purseUUID
        case machineNumber
        case selection
        case amount
        case article
        case machine
        case source
        case costCenterId
    }
}

// MARK: - VendingSendTransactionResponse

public struct VendingSendTransactionResponse: Codable {
    public let purseUUID: String
    public let balanceOld: Int64
    public let balanceNew: Int64
    public let totalGross: Int32
    public let terminalName: String?
    public let storeName: String?
    public let invoiceNumber: String?
    public let transactionUUID: String?
    public let costCenter: CostCenter?
    
    enum CodingKeys: String, CodingKey {
        case purseUUID
        case balanceOld
        case balanceNew
        case totalGross
        case terminalName
        case storeName
        case invoiceNumber
        case transactionUUID = "purseTransactionUUID"
        case costCenter
    }
}

/// Objective-C compatible wrapper for VendingSendTransactionResponse
@objc public class VendingSendTransactionResponseObjC: NSObject {
    @objc public let purseUUID: String
    @objc public let balanceOld: Int64
    @objc public let balanceNew: Int64
    @objc public let totalGross: Int32
    @objc public let terminalName: String?
    @objc public let storeName: String?
    @objc public let invoiceNumber: String?
    @objc public let transactionUUID: String?
    
    @objc public init(purseUUID: String, balanceOld: Int64, balanceNew: Int64, totalGross: Int32, terminalName: String?, storeName: String?, invoiceNumber: String?, transactionUUID: String?) {
        self.purseUUID = purseUUID
        self.balanceOld = balanceOld
        self.balanceNew = balanceNew
        self.totalGross = totalGross
        self.terminalName = terminalName
        self.storeName = storeName
        self.invoiceNumber = invoiceNumber
        self.transactionUUID = transactionUUID
        super.init()
    }
    
    convenience init(from response: VendingSendTransactionResponse) {
        self.init(
            purseUUID: response.purseUUID,
            balanceOld: response.balanceOld,
            balanceNew: response.balanceNew,
            totalGross: response.totalGross,
            terminalName: response.terminalName,
            storeName: response.storeName,
            invoiceNumber: response.invoiceNumber,
            transactionUUID: response.transactionUUID
        )
    }
}

// MARK: - VendingTransactionResult

/// Transaction result from a vending operation (Objective-C compatible)
@objc public class VendingTransactionResult: NSObject {
    @objc public let selection: Int32
    @objc public let amount: Int32
    @objc public let fingerprint: UInt32
    @objc public let article: VendingArticleObjC?
    @objc public let transactionResponse: VendingSendTransactionResponseObjC?
    
    // Convenience properties for easy access to transaction details
    @objc public var terminalName: String? {
        return transactionResponse?.terminalName
    }
    
    @objc public var storeName: String? {
        return transactionResponse?.storeName
    }
    
    @objc public var transactionUUID: String? {
        return transactionResponse?.transactionUUID
    }
    
    // Internal properties for Swift access to original structs
    public let articleStruct: VendingArticle?
    public let transactionResponseStruct: VendingSendTransactionResponse?
    
    @objc public init(selection: Int32, amount: Int32, fingerprint: UInt32, article: VendingArticleObjC?, transactionResponse: VendingSendTransactionResponseObjC?) {
        self.selection = selection
        self.amount = amount
        self.fingerprint = fingerprint
        self.article = article
        self.transactionResponse = transactionResponse
        self.articleStruct = nil
        self.transactionResponseStruct = nil
        super.init()
    }
    
    // Public initializer for Swift that accepts structs and converts them
    // Uses different parameter names (articleStruct/transactionResponseStruct) to avoid ambiguity with the @objc initializer
    public init(selection: Int32, amount: Int32, fingerprint: UInt32, articleStruct: VendingArticle?, transactionResponseStruct: VendingSendTransactionResponse?) {
        self.selection = selection
        self.amount = amount
        self.fingerprint = fingerprint
        self.article = articleStruct.map { VendingArticleObjC(from: $0) }
        self.transactionResponse = transactionResponseStruct.map { VendingSendTransactionResponseObjC(from: $0) }
        self.articleStruct = articleStruct
        self.transactionResponseStruct = transactionResponseStruct
        super.init()
    }
}

