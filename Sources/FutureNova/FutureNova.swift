import Foundation

public typealias CompletionHandler<Success> = (_ result: Result<Success, NetworkingError>) -> Void

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
    case decodingError(Error, Data, URLResponse?)
    case urlSessionError(Error)
    case invalidPath(String)
    
    public var description: String {
        switch self {
            case .uncategorized(let string): return "Uncategorized: \(string)"
            case .decodingError(let error, _, _): return error.localizedDescription
            case .invalidPath(let path): return "URL not found: \(path)"
            case .urlSessionError(let error): return "Session error: \(error.localizedDescription)"
        }
    }
}

public class NetworkManager {
    static let defaultSession = URLSession(configuration: .default)
    let host: String
    
    public var decoder: JSONDecoder
    public var encoder: JSONEncoder

    public init(
        host: String,
        decoder: JSONDecoder? = nil,
        encoder: JSONEncoder? = nil
    ) {
        self.host = host
        self.decoder = decoder ?? {
            let dec = JSONDecoder()
            if #available(macOS 10.12, *), #available(iOS 10.0, *) {
                dec.dateDecodingStrategy = .iso8601
            }
            return dec
        }()
        self.encoder = encoder ?? JSONEncoder()
    }
    
    func createRequest(
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
}

public class FutureNova: NetworkManager {
    private func dispatchDataTask<Success: Codable>(
        request: URLRequest,
        completionHandler: @escaping CompletionHandler<Success>) {
        
        let dataTask = Self.defaultSession.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { completionHandler(.failure(.uncategorized("self does not exist"))); return }
            if let error = error {
                DispatchQueue.main.async {
                    completionHandler(.failure(.urlSessionError(error)))
                }
                return
            } else if let data = data {
                do {
                    let decodedData = try self.decoder.decode(Success.self, from: data)
                    DispatchQueue.main.async {
                        completionHandler(.success(decodedData))
                    }
                    return
                } catch {
                    DispatchQueue.main.async {
                        completionHandler(.failure(.decodingError(error, data, response)))
                    }
                    return
                }
            } else {
                DispatchQueue.main.async {
                    completionHandler(.failure(.uncategorized("No data recieved")))
                }
                return
            }
        }
        dataTask.resume()
    }
    
    public func networkRequest<Body: Codable, Success: Codable>(
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
    
    public func bodylessRequest<Success: Codable>(
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
    
    public func delete<Body: Codable, Success: Codable>(
        route: String,
        parameters: CustomStringConvertible...,
        content: Body? = nil,
        completionHandler: @escaping CompletionHandler<Success>
    ) {
        networkRequest(route: route, parameters: parameters, requestType: .delete, content: content, completionHandler: completionHandler)
    }
    
    public func post<Body: Codable, Success: Codable>(
        route: String,
        parameters: CustomStringConvertible...,
        content: Body? = nil,
        completionHandler: @escaping CompletionHandler<Success>
    ) {
        networkRequest(route: route, parameters: parameters, requestType: .post, content: content, completionHandler: completionHandler)
    }
}

@available(macOS 12.0, *)
@available(iOS 15.0, *)
public class AsyncFutureNova: NetworkManager {
    public func networkRequest<Body: Codable, Success: Codable>(
        route: String,
        parameters: CustomStringConvertible...,
        requestType: RequestType,
        content: Body? = nil
    ) async throws -> Success {
        var request = try createRequest(route: route, parameters: parameters, requestType: requestType)
        try request.setContent(content: content, encoder: encoder)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        do {
            return try self.decoder.decode(Success.self, from: data)
        } catch {
            throw NetworkingError.decodingError(error, data, response)
        }
    }
    
    public func bodylessRequest<Success: Codable>(
        route: String,
        parameters: CustomStringConvertible...,
        requestType: RequestType
    ) async throws -> Success {
        let request = try createRequest(route: route, parameters: parameters, requestType: requestType)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        do {
            return try self.decoder.decode(Success.self, from: data)
        } catch {
            throw NetworkingError.decodingError(error, data, response)
        }
    }
    
    public func get<Success: Codable>(
        route: String,
        parameters: CustomStringConvertible...
    ) async throws -> Success {
        try await bodylessRequest(route: route, parameters: parameters, requestType: .get)
    }
    
    public func update<Body: Codable, Success: Codable>(
        route: String,
        parameters: CustomStringConvertible...,
        content: Body? = nil
    ) async throws -> Success {
        try await networkRequest(route: route, parameters: parameters, requestType: .put, content: content)
    }
    
    public func post<Body: Codable, Success: Codable>(
        route: String,
        parameters: CustomStringConvertible...,
        content: Body?
    ) async throws -> Success {
        try await networkRequest(route: route, parameters: parameters, requestType: .post, content: content)
    }
    
    public func delete<Body: Codable, Success: Codable>(
        route: String,
        parameters: CustomStringConvertible...,
        content: Body?
    ) async throws -> Success {
        try await networkRequest(route: route, parameters: parameters, requestType: .delete, content: content)
    }
}
