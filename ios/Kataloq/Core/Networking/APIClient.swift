import Foundation

/// Sends an `Endpoint` to kataloq-api and decodes the JSON response.
/// The seam that lets repositories be tested without a network.
protocol APIClient: Sendable {
    /// - Throws: `APIError` for transport/HTTP/decoding failures, `CancellationError` if the task was cancelled.
    func send<Response: Decodable>(_ endpoint: Endpoint, as responseType: Response.Type) async throws -> Response
}
