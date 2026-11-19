import Foundation

/// Body of `POST /api/v1/enquiries`. Optional fields that are nil are omitted from the JSON.
struct EnquiryRequest: Encodable, Equatable, Sendable {
    let productId: String
    let name: String
    let email: String
    let phone: String?
    let message: String?
}

/// `202 Accepted` response: the email provider accepted the enquiry.
struct EnquiryConfirmation: Decodable, Equatable, Sendable {
    let enquiryId: String
    let status: String
}
