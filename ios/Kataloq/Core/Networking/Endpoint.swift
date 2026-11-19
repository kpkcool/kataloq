import Foundation

enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
}

/// Describes one API call. Pure data, so repositories can be tested by inspecting it.
struct Endpoint: Equatable, Sendable {
    let method: HTTPMethod
    /// Path relative to the API base URL, e.g. "/api/v1/products/featured". Not percent-encoded.
    let path: String
    let queryItems: [URLQueryItem]
    let body: Data?

    static func get(_ path: String, queryItems: [URLQueryItem] = []) -> Endpoint {
        Endpoint(method: .get, path: path, queryItems: queryItems, body: nil)
    }

    static func post<Body: Encodable>(_ path: String, body: Body) throws -> Endpoint {
        Endpoint(method: .post, path: path, queryItems: [], body: try JSONEncoder().encode(body))
    }
}
