//
//  connect_x_mobile_sdk_swift.swift
//  connect_x_mobile_sdk_swift
//
//  Created by Surasak on 13/12/2567 BE.
//

import Foundation
import UIKit

class connect_x_mobile_sdk_swift {
    
    // Shared instance for singleton pattern
        public static let shared = connect_x_mobile_sdk_swift()

        private var token: String = ""
        private var startTime: Date = Date()
        private let generateCookieUrl = "https://connect-x-back-stable.herokuapp.com/connectx/api/ip/generateCookieV2"
        private let apiDomain = "abc"

        private init() {}
        
        // Initialize the SDK with a token
        public func initialize(withToken token: String) {
            self.token = token
            self.startTime = Date()
        }

        // Get client data (device info, locale, user agent)
        public func getClientData(completion: @escaping (Result<[String: Any], Error>) -> Void) {
            var clientData: [String: Any] = [
                "cx_isBrowser": false,
                "cx_language": Locale.current.language.languageCode?.identifier ?? "en",
                "cx_userAgent": self.getUserAgent()
            ]
            
            if let device = UIDevice.current.identifierForVendor?.uuidString {
                clientData["cx_fingerprint"] = device
            }
            
            // Get cookie and other client data
            self.getCookie { result in
                switch result {
                case .success(let cookie):
                    clientData["cx_cookie"] = cookie
                    clientData["cx_timespent"] = Int(Date().timeIntervalSince(self.startTime))
                    completion(.success(clientData))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }

        // Get the user agent string
        private func getUserAgent() -> String {
            return UIWebView().stringByEvaluatingJavaScript(from: "navigator.userAgent") ?? "Unknown"
        }

        // Get a cookie (from the server)
        private func getCookie(completion: @escaping (Result<String, Error>) -> Void) {
            guard let url = URL(string: generateCookieUrl) else {
                completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    completion(.failure(NSError(domain: "No data received", code: -1, userInfo: nil)))
                    return
                }
                
                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                       let cookie = jsonResponse["cookie"] as? String {
                        completion(.success(cookie))
                    } else {
                        completion(.failure(NSError(domain: "Cookie not found", code: -1, userInfo: nil)))
                    }
                } catch {
                    completion(.failure(error))
                }
            }
            
            task.resume()
        }
        
        // Private function for making POST requests
        private func cxPost(endpoint: String, data: [String: Any], completion: @escaping (Result<Void, Error>) -> Void) {
            guard let url = URL(string: "\(apiDomain)\(endpoint)") else {
                completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(self.token)", forHTTPHeaderField: "Authorization")
            
            do {
                let bodyData = try JSONSerialization.data(withJSONObject: data, options: [])
                request.httpBody = bodyData
            } catch {
                completion(.failure(error))
                return
            }
            
            let task = URLSession.shared.dataTask(with: request) { _, _, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                completion(.success(()))
            }
            
            task.resume()
        }
        
        // Public Tracking Methods
        public func cxTracking(body: [String: Any], completion: @escaping (Bool) -> Void) {
            print("cxTracking - Using Token: \(token) -- body is \(body)")
            self.getClientData { result in
                switch result {
                case .success(let clientData):
                    var data = body
                    data["cx_behavior"] = body["cx_behavior"] ?? ""
                    data.merge(clientData) { _, new in new }
                    
                    self.cxPost(endpoint: "/webtracking", data: data) { result in
                        // Handle the Result type correctly
                        switch result {
                        case .success:
                            completion(true) // Indicate success
                        case .failure:
                            completion(false) // Indicate failure
                        }
                    }
                case .failure:
                    completion(false)
                }
            }
        }

        
        public func cxIdentify(key: String, customers: [String: Any], tracking: [String: Any], form: [String: Any]?, options: [String: Any], completion: @escaping (Bool) -> Void) {
            self.getClientData { result in
                switch result {
                case .success(let clientData):
                    var data: [String: Any] = [
                        "key": key,
                        "customers": customers,
                        "tracking": tracking.merging(clientData) { _, new in new },
                        "form": form ?? [:],
                        "options": options
                    ]
                    
                    self.cxPost(endpoint: "/webtracking/dropform", data: data) { result in
                        switch result {
                        case .success:
                            completion(true) // Indicate success
                        case .failure:
                            completion(false) // Indicate failure
                        }
                    }
                case .failure:
                    completion(false)
                }
            }
        }
        
        public func cxOpenTicket(body: [String: Any], completion: @escaping (Bool) -> Void) {
            self.getClientData { result in
                switch result {
                case .success(let clientData):
                    var data = body
                    if var ticket = body["ticket"] as? [String: Any] {
                        ticket["organizeId"] = ticket["organizeId"] ?? ""
                        data["ticket"] = ticket
                    } else {
                        data["ticket"] = ["organizeId": ""]
                    }
                    
                    data.merge(clientData) { _, new in new }
                    
                    self.cxPost(endpoint: "/webtracking/dropformOpenTicket", data: data) { result in
                        switch result {
                        case .success:
                            completion(true)
                        case .failure:
                            completion(false)
                        }
                    }
                case .failure:
                    completion(false)
                }
            }
        }


}
