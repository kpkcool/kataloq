import Foundation

protocol EnquiryRepository: Sendable {
    /// Resolves only when the backend confirms the email was accepted (HTTP 202).
    func submit(_ enquiry: EnquiryRequest) async throws -> EnquiryConfirmation
}

final class RemoteEnquiryRepository: EnquiryRepository {
    private let apiClient: any APIClient

    init(apiClient: any APIClient) {
        self.apiClient = apiClient
    }

    func submit(_ enquiry: EnquiryRequest) async throws -> EnquiryConfirmation {
        let endpoint = try Endpoint.post("/api/v1/enquiries", body: enquiry)
        return try await apiClient.send(endpoint, as: EnquiryConfirmation.self)
    }
}
