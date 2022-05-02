import Foundation

public struct FutureNova {
    static let defaultSession = URLSession(configuration: .default)
    
    public typealias CompletionHandler<Success> = (_ result: Result<Success, NetworkingError>) -> Void
    
    public var decoder: JSONDecoder = {
        let dec = JSONDecoder()
        if #available(macOS 10.12, *) {
            dec.dateDecodingStrategy = .iso8601
        }
        return dec
    }()
    
    public var encoder: JSONEncoder
    
    public enum RequestType: CustomStringConvertible {
        case get
        case post
        case delete
        case update, put
        
        public var description: String {
            switch self {
                case .get: return "GET"
                case .post: return "POST"
                case .delete: return "DELETE"
                case .update, .put: return "PUT"
            }
        }
    }
    
    public enum NetworkingError: Error, CustomStringConvertible {
        case uncategorized(String)
        case decodingError(Error, Data)
        case urlSessionError(Error)
        case invalidPath(String)
        
        public var description: String {
            switch self {
                case .uncategorized(let string): return "Uncategorized: \(string)"
                case .decodingError(let error, _): return error.localizedDescription
                case .invalidPath(let path): return "URL not found: \(path)"
                case .urlSessionError(let error): return "Session error: \(error.localizedDescription)"
            }
        }
    }
    
    public private(set) var text = "Hello, World!"

    private var host: String
    
    public init(
        host: String,
        decoder: JSONDecoder? = nil,
        encoder: JSONEncoder? = nil
    ) {
        self.host = host
        if let decoder = decoder {
            self.decoder = decoder
        }
        if let encoder = encoder {
            self.encoder = encoder
        } else {
            self.encoder = JSONEncoder()
        }
    }
    
    private func createRequest(
        route: String,
        parameters: CustomStringConvertible...,
        requestType: RequestType
    ) throws -> URLRequest {
        let parameters = parameters
            .map(\.description)
            .reduce("", +/)
        
        let path = host +/ route +/ parameters
        guard let url = URL(string: path) else {
            throw NetworkingError.invalidPath(path)
        }
        
        return URLRequest(url: url)
    }
    
    private func dispatchDataTask<Success: Codable>(
        request: URLRequest,
        completionHandler: @escaping CompletionHandler<Success>) {
        
        let dataTask = Self.defaultSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completionHandler(.failure(.urlSessionError(error)))
                return
            } else if let data = data {
                do {
                    let decodedData = try decoder.decode(Success.self, from: data)
                    completionHandler(.success(decodedData))
                } catch {
                    completionHandler(.failure(.decodingError(error, data)))
                }
            } else {
                completionHandler(.failure(.uncategorized("No data recieved")))
            }
        }
        dataTask.resume()
    }
    
    private func networkRequest<Body: Codable, Success: Codable>(
        route: String,
        parameters: CustomStringConvertible...,
        requestType: RequestType,
        content: Body? = nil,
        completionHandler: @escaping CompletionHandler<Success>
    ) {
        do {
            var request = try createRequest(route: route, parameters: parameters, requestType: requestType)
            try request.setContent(content: content, encoder: encoder)
            dispatchDataTask(request: request, completionHandler: completionHandler)
        } catch {
            completionHandler(.failure(.urlSessionError(error)))
        }
    }
    
    private func bodylessRequest<Success: Codable>(
        route: String,
        parameters: CustomStringConvertible...,
        requestType: RequestType,
        completionHandler: @escaping CompletionHandler<Success>
    ) {
        do {
            let request = try createRequest(route: route, parameters: parameters, requestType: requestType)
            dispatchDataTask(request: request, completionHandler: completionHandler)
        } catch {
            completionHandler(.failure(.urlSessionError(error)))
        }
    }
    
    public func get<Success: Codable>(
        route: String,
        parameters: CustomStringConvertible...,
        requestType: RequestType,
        completionHandler: @escaping CompletionHandler<Success>) {
            bodylessRequest(route: route, parameters: parameters, requestType: .get, completionHandler: completionHandler)
    }
    
    public func update<Body: Codable, Success: Codable>(
        route: String,
        parameters: CustomStringConvertible...,
        content: Body? = nil,
        completionHandler: @escaping CompletionHandler<Success>
    ) {
        networkRequest(route: route, parameters: parameters, requestType: .update, content: content, completionHandler: completionHandler)
    }
}
