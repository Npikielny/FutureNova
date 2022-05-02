//
//  File.swift
//  
//
//  Created by Noah Pikielny on 5/2/22.
//

import Foundation

extension StringProtocol {
    func endsWith<S: StringProtocol>(_ s: S) -> Bool {
        return String(suffix(s.count)) == String(s)
    }
}

precedencegroup NetworkingWrapper {
    associativity: left
}

infix operator +/ : NetworkingWrapper

extension String {
    static func +/ (lhs: String, rhs: String) -> String {
        return lhs + (lhs.endsWith("/") ? "" : "/") + rhs
    }
}

extension URLRequest {
    mutating func setContent<Body: Codable>(content: Body?, encoder: JSONEncoder) throws {
        guard let content = content else { return }
        let encodedData = try JSONEncoder().encode(content)
        addValue("application/json", forHTTPHeaderField: "Content-Type")
        addValue("application/json", forHTTPHeaderField: "accept")
        httpBody = encodedData
    }
}
