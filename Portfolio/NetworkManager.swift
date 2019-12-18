//
//  NetworkManager.swift
//  Portfolio
//
//  Created by John Woolsey on 1/26/16.
//  Copyright © 2016 ExtremeBytes Software. All rights reserved.
//


// Example network call: http://dev.markitondemand.com/MODApis/Api/quote/json?symbol=AAPL
// Note: The Market On Demand service that supplies the API used in this project has very limited bandwidth
//       so only a limited number of positions should be used.


import Foundation
import UIKit


// MARK: - Enumerations

enum NetworkError: Int, Error {
   case noConnection = 1 ,invalidRequest, invalidResponse, unknown
   
   var description: String {
      switch self {
      case .noConnection:
         return "No internet connection or the server could not be reached. Please check your settings and try again. Contact the vendor if you continue to see this issue."
      case .invalidRequest:
         return "Attempted to submit an invalid request to the server. Please try again. Contact the vendor if you continue to see this issue."
      case .invalidResponse:
         return "Received an invalid response from the server. Please try again. Contact the vendor if you continue to see this issue."
      case .unknown:
         return "An unknown network error occurred. Please try again. Please contact the vendor if you continue to see this issue."
      }
   }
   
   var error: Error {
      return NSError(domain: NetworkManager.shared.errorDomain,
                     code: hashValue,
                     userInfo: [NSLocalizedDescriptionKey: NSLocalizedString(description, comment: "")]) as Error
   }
}




class NetworkManager {
   
    // MARK: - Set RestManger Code
    let rest = RestManager.shared
    
    // MARK: - Properties
    
    var requestHttpHeaders = RestEntity()
    
    var urlQueryParameters = RestEntity()
    
    var httpBodyParameters = RestEntity()
    
    var httpBody: Data?
   
    static let shared = NetworkManager()  // singleton
   
    var isNetworkAvailable: Bool { return NetworkReachability.isConnectedToNetwork() }
   
   //private let baseURL = URL(string: "http://dev.markitondemand.com/MODApis/Api/quote/json")
    private let baseURL = URL(string:"https://api.worldtradingdata.com/api/v1/stock")
    
   //private let queryParameter = "symbol"
   
    private let queryParameter = "symbol"
    

    let baseParams = ["api_token" : "iiJAjjHVtrYbeGF1rKV3hmstTRRYi4MW12YEmaQtwE26GYw5HMMXmLm7JEbY"]
    
    private let maximumOperationsPerSecond = 5  // service is limited to about 10 operations per second, but sometimes drastically lower
    fileprivate let errorDomain = "com.extremebytes.portfolio"
   
    private var operationsQueue: [URLSessionTask] = []
    private var operationTimer: Timer?
    private var operationsInProgress = 0 {
      didSet {
         if operationsInProgress > 0 {
            showNetworkIndicator()
            if operationTimer == nil || operationTimer?.isValid == false {
               operationTimer = Timer.scheduledTimer(timeInterval: 1.1,
                                                     target: self,
                                                     selector: #selector(fetchTimerFired(_:)),
                                                     userInfo: nil,
                                                     repeats: true)
            }
         } else {
            operationTimer?.invalidate()
            operationTimer = nil
            hideNetworkIndicator()
         }
      }
   }
   
   
   // MARK: - Lifecycle
   
   private init() {}  // prevents use of default initializer
   
   
   // MARK: - Actions
   
   /**
    Requests a batch of network jobs to be submitted when the fetch timer is fired.
    
    - parameter sender: The object that requested the action.
    */
   @objc func fetchTimerFired(_ sender: Timer) {  // @objc required for recognizing method selector signature
      #if DEBUG
         print("Fetch timer fired.")
      #endif
      batchJobs()
   }
    
 
   // MARK: - Network Operations
    
    
    
    
   
   /**
    Fetches details for an investment position from the server.
    
    - parameter symbol:     The ticker symbol representing the investment.
    - parameter completion: A closure that is executed upon completion.
    */
   func fetchPosition(for symbol: String, completion: @escaping (_ results: Results?, _ error: Error?) -> Void) {
        var error: Error?
     
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let url = URL(string: "https://api.worldtradingdata.com/api/v1/stock?symbol=\(symbol)&api_token=iiJAjjHVtrYbeGF1rKV3hmstTRRYi4MW12YEmaQtwE26GYw5HMMXmLm7JEbY") else { return
                 
            }
            
            let httpBody = self?.getHttpBody()
            
            guard let request = self?.prepareRequest(withURL: url, httpBody: httpBody, httpMethod: .get) else
            {
                completion(Results(withError: CustomError.failedToCreateRequest), error)
                return
            }
            
            let sessionConfiguration = URLSessionConfiguration.default
            let session = URLSession(configuration: sessionConfiguration)
            let task = session.dataTask(with: request) { (data, response, error) in
                completion(Results(withData: data,
                                   response: Response(fromURLResponse: response),
                                   error: error), error)
            }
            task.resume()
        }
    
    
        // The following will make RestManager create the following URL:
        // https://reqres.in/api/users?page=2
//        RestManager.shared.urlQueryParameters.add(value: symbol, forKey: "symbol")
//        RestManager.shared.urlQueryParameters.add(value: "iiJAjjHVtrYbeGF1rKV3hmstTRRYi4MW12YEmaQtwE26GYw5HMMXmLm7JEbY", forKey: "api_token")
        
//        RestManager.shared.makeRequest(toURL: url, withHttpMethod: .get) { (results) in
//            if let data = results.data {
//                let decoder = JSONDecoder()
//                //decoder.keyDecodingStrategy = .convertFromSnakeCase
//                guard let positionsData = try? decoder.decode(PositionsData.self, from: data) else { return }
//
//                print(positionsData)
//
//                position = Position()
//
//                position?.status = "open"
//
//                if let symbol = positionsData.data?[0].symbol {
//                    position?.symbol = symbol
//                }
//
//                if let name = positionsData.data?[0].name {
//                    position?.name = name
//                }
//
//                if let lastPrice = positionsData.data?[0].price {
//                    position?.lastPrice = Double(lastPrice)
//                }
//
//                if let change = positionsData.data?[0].day_change {
//                    position?.change = Double(change)
//                }
//
//                if let changePercent = positionsData.data?[0].change_pct {
//                    position?.changePercent = Double(changePercent)
//                }
//
//                position?.timeStamp = positionsData.data?[0].last_trade_time
//
//                if let marketCap = positionsData.data?[0].market_cap {
//                    position?.marketCap = Double(marketCap)
//                }
//
//                if let volume = positionsData.data?[0].volume {
//                    position?.volume = Double(volume)
//                }
//
//                if let changeYTD = positionsData.data?[0].day_change {
//                    position?.changeYTD = Double(changeYTD)
//                }
//
//                if let changePercentYTD = positionsData.data?[0].change_pct {
//                    position?.changePercentYTD = Double(changePercentYTD)
//                }
//
//                if let high = positionsData.data?[0].day_high {
//                    position?.high = Double(high)
//                }
//
//                if let low = positionsData.data?[0].day_low {
//                    position?.low = Double(low)
//                }
//
//                if let open = positionsData.data?[0].price_open {
//                    position?.open = Double(open)
//                }
//            }
//
//            print("\n\nResponse HTTP Headers:\n")
//
//            if let response = results.response {
//                for (key, value) in response.headers.allValues() {
//                    print(key, value)
//                }
//            }
//
//            // Execute completion handler
//            DispatchQueue.main.async {
//                    completion(position, error)
//            }
//        }
   }
   
   
    // MARK: - Other
    
    private func prepareRequest(withURL url: URL?, httpBody: Data?, httpMethod: HttpMethod) -> URLRequest? {
        guard let url = url else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = httpMethod.rawValue
        
        for (header, value) in requestHttpHeaders.allValues() {
            request.setValue(value, forHTTPHeaderField: header)
        }
        
        request.httpBody = httpBody
        return request
    }
    
    private func getHttpBody() -> Data? {
        guard let contentType = requestHttpHeaders.value(forKey: "Content-Type") else { return nil }
        
        if contentType.contains("application/json") {
            return try? JSONSerialization.data(withJSONObject: httpBodyParameters.allValues(), options: [.prettyPrinted, .sortedKeys])
        } else if contentType.contains("application/x-www-form-urlencoded") {
            let bodyString = httpBodyParameters.allValues().map { "\($0)=\(String(describing: $1.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)))" }.joined(separator: "&")
            return bodyString.data(using: .utf8)
        } else {
            return httpBody
        }
    }
   
   /**
    Hides the status bar network indicator.
    */
   func hideNetworkIndicator() {
      DispatchQueue.main.async {
         UIApplication.shared.isNetworkActivityIndicatorVisible = false
      }
   }
   
   
   /**
    Shows the status bar network indicator.
    */
   func showNetworkIndicator() {
      DispatchQueue.main.async {
         UIApplication.shared.isNetworkActivityIndicatorVisible = true
      }
   }
   
   
   /**
    Submits a batch of network jobs.
    */
   private func batchJobs() {
      guard isNetworkAvailable else {
         let error = NetworkError.noConnection.error
         AppCoordinator.shared.presentErrorToUser(title: "Network Unvailable", message: error.localizedDescription)
         return
      }
      
      let numberOfBatchTasks = operationsQueue.count < maximumOperationsPerSecond ?
         operationsQueue.count : maximumOperationsPerSecond
      #if DEBUG
         print("Number of batch tasks: \(numberOfBatchTasks)")
      #endif
      for task in operationsQueue[0..<numberOfBatchTasks] {
         task.resume()
      }
      operationsQueue.removeFirst(numberOfBatchTasks)
   }
}

extension NetworkManager {
    struct RestEntity {
        private var values: [String: String] = [:]
        
        mutating func add(value: String, forKey key: String) {
            values[key] = value
        }
        
        func value(forKey key: String) -> String? {
            return values[key]
        }
        
        func allValues() -> [String: String] {
            return values
        }
        
        func totalItems() -> Int {
            return values.count
        }
    }
    
    enum HttpMethod: String {
        case get
        case post
        case put
        case patch
        case delete
    }
    
    struct Response {
            var response: URLResponse?
            var httpStatusCode: Int = 0
            var headers = RestEntity()
            
            init(fromURLResponse response: URLResponse?) {
                guard let response = response else { return }
                self.response = response
                httpStatusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                
                if let headerFields = (response as? HTTPURLResponse)?.allHeaderFields {
                    for (key, value) in headerFields {
                        headers.add(value: "\(value)", forKey: "\(key)")
                    }
                }
            }
        }
        
        
        
        struct Results {
            var data: Data?
            var response: Response?
            var error: Error?
            
            init(withData data: Data?, response: Response?, error: Error?) {
                self.data = data
                self.response = response
                self.error = error
            }
            
            init(withError error: Error) {
                self.error = error
            }
        }

            
            
        enum CustomError: Error {
            case failedToCreateRequest
        }
    }


    // MARK: - Custom Error Description
    extension NetworkManager.CustomError: LocalizedError {
        public var localizedDescription: String {
            switch self {
            case .failedToCreateRequest: return NSLocalizedString("Unable to create the URLRequest object", comment: "")
            }
    }
}
