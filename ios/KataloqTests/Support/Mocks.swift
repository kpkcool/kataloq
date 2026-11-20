import UIKit
@testable import Kataloq

enum MockError: Error, Equatable {
    case notStubbed
}

/// Records endpoints and decodes a canned JSON body, so repository tests also exercise decoding.
/// `@unchecked Sendable`: only touched from one test at a time.
final class MockAPIClient: APIClient, @unchecked Sendable {
    private(set) var requestedEndpoints: [Endpoint] = []
    var responseJSON = "{}"
    var error: Error?

    func send<Response: Decodable>(_ endpoint: Endpoint, as responseType: Response.Type) async throws -> Response {
        requestedEndpoints.append(endpoint)
        if let error { throw error }
        return try JSONDecoder().decode(Response.self, from: Data(responseJSON.utf8))
    }
}

final class MockProductRepository: ProductRepository, @unchecked Sendable {
    var featuredResult: Result<[Product], Error> = .success([])
    var allProductsResult: Result<[Product], Error> = .success([])
    var categoriesResult: Result<[ProductCategory], Error> = .success([])
    var categoryProductsResult: Result<CategoryProducts, Error> = .failure(MockError.notStubbed)
    var searchResult: Result<[Product], Error> = .success([])
    var productResult: Result<Product, Error> = .failure(MockError.notStubbed)

    private(set) var calls: [String] = []

    func featuredProducts() async throws -> [Product] {
        calls.append("featuredProducts")
        return try featuredResult.get()
    }

    func allProducts() async throws -> [Product] {
        calls.append("allProducts")
        return try allProductsResult.get()
    }

    func categories() async throws -> [ProductCategory] {
        calls.append("categories")
        return try categoriesResult.get()
    }

    func categoryProducts(categoryID: String) async throws -> CategoryProducts {
        calls.append("categoryProducts:\(categoryID)")
        return try categoryProductsResult.get()
    }

    func searchProducts(matching query: String) async throws -> [Product] {
        calls.append("searchProducts:\(query)")
        return try searchResult.get()
    }

    func product(id: String) async throws -> Product {
        calls.append("product:\(id)")
        return try productResult.get()
    }
}

final class MockEnquiryRepository: EnquiryRepository, @unchecked Sendable {
    var result: Result<EnquiryConfirmation, Error> = .success(EnquiryConfirmation(enquiryId: "e1", status: "sent"))
    private(set) var submitted: [EnquiryRequest] = []

    func submit(_ enquiry: EnquiryRequest) async throws -> EnquiryConfirmation {
        submitted.append(enquiry)
        return try result.get()
    }
}

/// Never loads anything: cells keep their placeholder.
@MainActor
final class MockImageLoader: ImageLoading {
    private(set) var requestedURLs: [URL] = []

    func image(for url: URL) async -> UIImage? {
        requestedURLs.append(url)
        return nil
    }
}
