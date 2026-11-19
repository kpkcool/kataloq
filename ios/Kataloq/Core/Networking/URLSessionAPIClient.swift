import Foundation

/// `APIClient` backed by URLSession. Validates HTTP status, decodes kataloq-api's error body,
/// maps URLError to `APIError`, and turns cancellation into `CancellationError` so callers can ignore it.
final class URLSessionAPIClient: APIClient {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL, session: URLSession = URLSessionAPIClient.makeDefaultSession()) {
        self.baseURL = baseURL
        self.session = session
    }

    /// 15 s per request: the backend's own upstream timeout is 5 s, plus headroom.
    static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    func send<Response: Decodable>(_ endpoint: Endpoint, as responseType: Response.Type) async throws -> Response {
        let request = try makeRequest(for: endpoint)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .cancelled: throw CancellationError()
            case .timedOut: throw APIError.timeout
            default: throw APIError.transport(error.code)
            }
        }

        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let errorBody = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            throw APIError.server(
                status: httpResponse.statusCode,
                code: errorBody?.error.code,
                message: errorBody?.error.message,
                fieldErrors: errorBody?.error.details ?? []
            )
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    func makeRequest(for endpoint: Endpoint) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidRequest
        }
        let basePath = components.path.hasSuffix("/") ? String(components.path.dropLast()) : components.path
        components.path = basePath + endpoint.path

        // URLComponents leaves "+" and "&" unescaped in query values; the server would read "+" as a space.
        components.percentEncodedQueryItems = endpoint.queryItems.isEmpty
            ? nil
            : endpoint.queryItems.map { item in
                URLQueryItem(
                    name: item.name,
                    value: item.value?.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed)
                )
            }

        guard let url = components.url else { throw APIError.invalidRequest }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = endpoint.body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }
}

private extension CharacterSet {
    /// Characters allowed unescaped in a query *value*: the query set minus the separators.
    static var urlQueryValueAllowed: CharacterSet {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=?#")
        return allowed
    }
}
