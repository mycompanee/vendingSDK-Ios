//
//  AuthenticationService.swift
//  VendingIosSDK
//
//  Created on $(DATE).
//

import Foundation

class AuthenticationService {
    static let shared = AuthenticationService()
    
    private var accessToken: String?
    private var refreshToken: String?
    private var tokenExpiryDate: Date?
    
    private let clientId = "mobileapp"
    private let clientSecret = "14317cd9-4bc3-4cbc-af7a-c767038cd0c0"
    private let scope = "openid profile IdentityServerApi offline_access client_api notification_api payment_api"
    
    private init() {}
    
    var currentAccessToken: String? {
        // Check if token is still valid
        if let expiry = tokenExpiryDate, expiry > Date() {
            return accessToken
        }
        return nil
    }
    
    var currentTenantId: String? {
        guard let token = accessToken else {
            return nil
        }
        return extractTenantId(from: token)
    }
    
    private func extractTenantId(from token: String) -> String? {
        // JWT tokens have three parts separated by dots: header.payload.signature
        let parts = token.components(separatedBy: ".")
        guard parts.count == 3 else {
            return nil
        }
        
        // Decode the payload (second part)
        var base64String = parts[1]
        
        // Add padding if needed
        let remainder = base64String.count % 4
        if remainder > 0 {
            base64String = base64String.padding(toLength: base64String.count + 4 - remainder, withPad: "=", startingAt: 0)
        }
        
        // Replace URL-safe characters
        base64String = base64String.replacingOccurrences(of: "-", with: "+")
        base64String = base64String.replacingOccurrences(of: "_", with: "/")
        
        guard let data = Data(base64Encoded: base64String),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tenantId = json["tenantId"] as? String else {
            return nil
        }
        
        return tenantId
    }
    
    private var userServiceBaseUrl: String {
        return Config.userServiceBaseUrl
    }
    
    func authenticate(authKey: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Use authKey directly as access token
        guard !authKey.isEmpty else {
            completion(.failure(NSError(domain: "AuthenticationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "AuthKey cannot be empty"])))
            return
        }
        
        // Store the authKey as the access token
        self.accessToken = authKey
        
        // Set a long expiry date (1 year) since we don't have expiry info from the authKey
        self.tokenExpiryDate = Date().addingTimeInterval(365 * 24 * 60 * 60)
        self.refreshToken = nil
        
        completion(.success(authKey))
    }
    
    func logout() {
        accessToken = nil
        refreshToken = nil
        tokenExpiryDate = nil
    }
}

