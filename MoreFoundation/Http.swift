/// Copyright (c) 2017-19 Nicolas Christe
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in all
/// copies or substantial portions of the Software.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
/// SOFTWARE.

import Foundation

/// Extends Array<URLQueryItem> to build from and extract to a dictionnary query params as disctionnary
public extension Array where Element == URLQueryItem {

    /// Get a dictionnary containing Query items
    var asDictionnary: [String: [String]] {
        return Dictionary(grouping: self, by: { $0.name }).mapValues { $0.compactMap { $0.value } }
    }

    /// Initializer from a dictionary of Query items
    ///
    /// - Parameter dictionary: dictionnary of key, values query item
    init(from dictionary: [String: [String]]) {
        self = dictionary.map { key, values in
            values.isEmpty ? [URLQueryItem(name: key, value: nil)] : values.map { URLQueryItem(name: key, value: $0) }
            }.flatMap { $0 }
    }

    /// get dictionnary of unique key: value. Duplicate values are ignored
    var asFlatDictionnary: [String: String?] {
        return Dictionary(self.map { ($0.name, $0.value) }, uniquingKeysWith: { first, _ in first })
    }

    /// Initializer from a dictionary of Query items
    ///
    /// - Parameter dictionary: dictionnary of key, values query item
    init(from dictionary: [String: String?]) {
        self = dictionary.map { URLQueryItem(name: $0.key, value: $0.value) }
    }
}

// MARK: - URLComponents
public extension URLComponents {
    /// query items as dictionary, supporting mulitple value for each key
    var queryParams: [String: [String]]? {
        get {
            return queryItems?.asDictionnary
        }
        set {
            if let newValue = newValue {
                queryItems = [URLQueryItem](from: newValue)
            } else {
                queryItems = nil
            }
        }
    }

    /// query items as dictionary, with a single value for each key
    var flatQueryParams: [String: String?]? {
        get {
            return queryItems?.asFlatDictionnary
        }
        set {
            if let newValue = newValue {
                queryItems = [URLQueryItem](from: newValue)
            } else {
                queryItems = nil
            }
        }
    }
}

// MARK: - URL
public extension URL {
    /// query items as dictionary, supporting mulitple value for each key
    var queryParams: [String: [String]]? {
        return URLComponents(url: self, resolvingAgainstBaseURL: false)?.queryParams
    }

    /// Create a new URL appending query parameters
    ///
    /// - Parameter queryParams: query parameters to append
    /// - Returns: new url
    func appending(queryParams: [String: [String]]) -> URL {
        if var urlComponents = URLComponents(url: self, resolvingAgainstBaseURL: false) {
            urlComponents.queryParams = queryParams
            return urlComponents.url ?? self
        }
        return self
    }

    /// query items as dictionary
    var flatQueryParams: [String: String?]? {
        return URLComponents(url: self, resolvingAgainstBaseURL: false)?.flatQueryParams
    }

    /// Create a new URL appending query parameters
    ///
    /// - Parameter queryParams: query parameters to append
    /// - Returns: new url
   func appending(queryParams: [String: String?]) -> URL {
        if var urlComponents = URLComponents(url: self, resolvingAgainstBaseURL: false) {
            urlComponents.flatQueryParams = queryParams
            return urlComponents.url ?? self
        }
        return self
    }
}

// MARK: - URL
public extension URL {
    /// URL safe constructor from a static string
    init(staticString string: StaticString) {
        guard let url = URL(string: "\(string)") else {
            fatal("Invalid static URL string: \(string)")
        }
        self = url
    }
}

// MARK: - URLRequest

/// Extends URLRequest to add constructor with parametres
public extension URLRequest {
    enum Method: String {
        case get = "GET"
        case post = "POST"
        case put = "PUT"
        case delete = "DELETE"
    }

    /// Constructor with URL, method, headers and string body
    ///
    /// - Parameters:
    ///   - url: request URL
    ///   - method: request methods
    ///   - headers: request headers
    ///   - body: body as UTF8 encoded string
    init(url: URL, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy, timeoutInterval: TimeInterval = 60.0,
         method: Method, headers: [String: String]? = nil, body: Data? = nil) {
        self.init(url: url, cachePolicy: cachePolicy, timeoutInterval: timeoutInterval)
        self.httpMethod = method.rawValue
        self.allHTTPHeaderFields = headers
        self.httpBody = body
    }

    /// Constructor with URL, method, headers and string body
    ///
    /// - Parameters:
    ///   - url: request URL
    ///   - method: request methods
    ///   - headers: request headers
    ///   - body: body as UTF8 encoded string
    init(url: URL, cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy, timeoutInterval: TimeInterval = 60.0,
         method: Method, headers: [String: String]? = nil, body: String) {
        self.init(url: url, method: method, headers: headers, body: body.data(using: .utf8))
    }
}

/// An HTTP error code
public enum HttpError: Error, Equatable {
    /// Error
    /// - Parameter: statusCode: http status code
    case error(statusCode: Int)
}

// MARK: - URLSession
public extension URLSession {

    /// Create and resume a datatask to read a resource
    ///
    /// - Parameters:
    ///   - request: url request
    ///   - additionalAcceptableStatusCodes: additionnal valid status code. 200 to 300 are already considered as valid
    ///     status codes.
    ///   - promise: promise to fullfill or reject when the datatask has been executed. Promise is rejected
    ///   if the task complete with a status code other that 2xx.
    func httpDataTask(request: URLRequest, additionalAcceptableStatusCodes: Set<Int> = [],
                      promise: Promise<(statusCode: Int, headers: [String: String], body: Data), Error>) {
        let dataTask = self.dataTask(with: request) { data, response, error in
            if let error = error {
                promise.reject(with: error)
            } else if let response = response as? HTTPURLResponse {
                if 200..<300 ~= response.statusCode || additionalAcceptableStatusCodes.contains(response.statusCode),
                    let headers = response.allHeaderFields as? [String: String], let data = data {
                    promise.fulfill(with: (response.statusCode, headers, data))
                } else {
                    promise.reject(with: HttpError.error(statusCode: response.statusCode))
                }
            } else {
                promise.reject(with: NSError(domain: NSURLErrorDomain, code: NSURLErrorUnknown, userInfo: nil))
            }
        }
        promise.registerCancel {
            dataTask.cancel()
        }
        dataTask.resume()
    }
}
