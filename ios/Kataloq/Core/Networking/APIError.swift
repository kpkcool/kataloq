import Foundation

enum APIError: Error, Equatable {
    /// The request never got an HTTP response (offline, server not running, DNS...).
    case transport(URLError.Code)
    /// No response within the timeout.
    case timeout
    /// Non-2xx response. `code`, `message` and `fieldErrors` come from kataloq-api's error body, if it had one.
    case server(status: Int, code: String?, message: String?, fieldErrors: [FieldError])
    /// A 2xx response whose body didn't match the expected contract.
    case decoding
    case invalidResponse
    case invalidRequest
}

/// Turns any error into copy that's safe and useful to show to a customer.
enum UserFacingError {
    static let generic = "Something went wrong. Please try again."

    static func message(for error: Error) -> String {
        guard let apiError = error as? APIError else { return generic }

        switch apiError {
        case .transport(let code):
            switch code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff:
                return "You appear to be offline. Check your connection and try again."
            default:
                return "Can't reach Kataloq right now. Please try again."
            }
        case .timeout:
            return "This is taking longer than expected. Please try again."
        case .server(_, _, let message?, _):
            // kataloq-api error messages are written to be shown to customers.
            return message
        case .server, .decoding, .invalidResponse, .invalidRequest:
            return generic
        }
    }
}
