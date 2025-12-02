//
//  ClientServiceAPI.swift
//  VendingIosSDK
//
//  Created on $(DATE).
//

import Foundation

class ClientServiceAPI {
    static let shared = ClientServiceAPI()
    private let authenticationService = AuthenticationService.shared
    
    private init() {}
    
    private var clientServiceBaseUrl: String {
        return Config.clientServiceBaseUrl
    }
    
    func getVendingBaseData(completion: @escaping (Result<VendingBaseDataResponse, Error>) -> Void) {
        guard let accessToken = authenticationService.currentAccessToken else {
            completion(.failure(NSError(domain: "ClientServiceAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated. Please login first."])))
            return
        }
        
        guard let url = URL(string: "\(clientServiceBaseUrl)/MobileApplication/GetVendingBaseData") else {
            completion(.failure(NSError(domain: "ClientServiceAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "ClientServiceAPI", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "ClientServiceAPI", code: -4, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Request failed with status code \(httpResponse.statusCode)"
                completion(.failure(NSError(domain: "ClientServiceAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let vendingBaseData = try decoder.decode(VendingBaseDataResponse.self, from: data)
                completion(.success(vendingBaseData))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    func getLocationsWithPurse(userId: String? = nil, completion: @escaping (Result<[GetLocationsWithPurseReponse], Error>) -> Void) {
        guard let accessToken = authenticationService.currentAccessToken else {
            completion(.failure(NSError(domain: "ClientServiceAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated. Please login first."])))
            return
        }
        
        var urlString = "\(clientServiceBaseUrl)/MobileApplication/GetLocationsWithPurse"
        if let userId = userId {
            urlString += "/\(userId)"
        }
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "ClientServiceAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "ClientServiceAPI", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "ClientServiceAPI", code: -4, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Request failed with status code \(httpResponse.statusCode)"
                completion(.failure(NSError(domain: "ClientServiceAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let locations = try decoder.decode([GetLocationsWithPurseReponse].self, from: data)
                completion(.success(locations))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    func sendVendingTransaction(_ request: VendingSendTransactionRequest, apiKey: String? = "afe7095e-vendingSDK-IOS", completion: @escaping (Result<VendingSendTransactionResponse, Error>) -> Void) {
        guard let accessToken = authenticationService.currentAccessToken else {
            completion(.failure(NSError(domain: "ClientServiceAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated. Please login first."])))
            return
        }
        
        guard let url = URL(string: "\(clientServiceBaseUrl)/MobileApplication/SendVendingTransaction") else {
            completion(.failure(NSError(domain: "ClientServiceAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let apiKey = apiKey {
            urlRequest.setValue(apiKey, forHTTPHeaderField: "apiKey")
        }
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        do {
            let encoder = JSONEncoder()
            urlRequest.httpBody = try encoder.encode(request)
        } catch {
            completion(.failure(error))
            return
        }
        
        let session = URLSession.shared
        let task = session.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "ClientServiceAPI", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "ClientServiceAPI", code: -4, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Request failed with status code \(httpResponse.statusCode)"
                completion(.failure(NSError(domain: "ClientServiceAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(VendingSendTransactionResponse.self, from: data)
                completion(.success(response))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    func getPurseByUUID(_ purseUUID: String, completion: @escaping (Result<Purse, Error>) -> Void) {
        guard let accessToken = authenticationService.currentAccessToken else {
            completion(.failure(NSError(domain: "ClientServiceAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated. Please login first."])))
            return
        }
        
        guard let url = URL(string: "\(clientServiceBaseUrl)/MobileApplication/GetPurseByUUID/\(purseUUID)") else {
            completion(.failure(NSError(domain: "ClientServiceAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "ClientServiceAPI", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "ClientServiceAPI", code: -4, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Request failed with status code \(httpResponse.statusCode)"
                completion(.failure(NSError(domain: "ClientServiceAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let purse = try decoder.decode(Purse.self, from: data)
                completion(.success(purse))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    /// Get purse using GET /Purse/Purse endpoint with apiKey header
    /// This is the endpoint for third-party API access
    /// - Parameters:
    ///   - authKey: Authentication key to use directly (passed from user)
    ///   - apiKey: API key (default: "afe7095e-vendingSDK-IOS" for iOS SDK)
    ///   - completion: Completion handler with Result containing Purse on success or Error on failure
    func getPurse(authKey: String, apiKey: String = "afe7095e-vendingSDK-IOS", completion: @escaping (Result<Purse, Error>) -> Void) {
        // Use third-party API base URL: https://3rdpartyapi.my.companee.cloud
        let thirdPartyApiBaseUrl = "https://3rdpartyapi.my.companee.cloud"
        
        guard let url = URL(string: "\(thirdPartyApiBaseUrl)/Purse/Purse") else {
            completion(.failure(NSError(domain: "ClientServiceAPI", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Use accessToken header (not Authorization) - matches Swagger UI format
        // The header should be the raw token value, not "Bearer {token}"
        request.setValue(authKey, forHTTPHeaderField: "accessToken")
        request.setValue(apiKey, forHTTPHeaderField: "apiKey")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        
        let session = URLSession.shared
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "ClientServiceAPI", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "ClientServiceAPI", code: -4, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            if httpResponse.statusCode != 200 {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Request failed with status code \(httpResponse.statusCode)"
                print("[ClientServiceAPI] Error: \(errorMessage)")
                completion(.failure(NSError(domain: "ClientServiceAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                // Decode the wrapper response from third-party API
                let response = try decoder.decode(ThirdPartyPurseResponse.self, from: data)
                let purse = response.purse
                print("[ClientServiceAPI] Retrieved purse - UUID: \(purse.uuid ?? "nil"), Balance: \(purse.balance ?? 0) cents")
                completion(.success(purse))
            } catch {
                print("[ClientServiceAPI] Failed to decode purse response: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
}

