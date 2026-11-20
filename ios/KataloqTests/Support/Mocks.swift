import UIKit
@testable import Kataloq

enum MockError: Error, Equatable {
    case notStubbed
}

/// A value guarded by a lock. Mocks record calls through it because ViewModels call
/// repositories concurrently (Home loads featured, categories and all products with
/// `async let`), so appends can arrive from several threads at once. An unguarded array
/// append from two threads can crash the test process.
final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withLock<T>(_ body: (inout Value) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

/// Records endpoints and decodes a canned JSON body, so repository tests also exercise decoding.
/// `@unchecked Sendable`: stubs are set by the test before the call; the record is lock-guarded.
final class MockAPIClient: APIClient, @unchecked Sendable {
    private let endpointLog = Locked<[Endpoint]>([])
    var requestedEndpoints: [Endpoint] { endpointLog.withLock { $0 } }
    var responseJSON = "{}"
    var error: Error?

    func send<Response: Decodable>(_ endpoint: Endpoint, as responseType: Response.Type) async throws -> Response {
        endpointLog.withLock { $0.append(endpoint) }
        if let error { throw error }
        return try JSONDecoder().decode(Response.self, from: Data(responseJSON.utf8))
    }
}

/// `@unchecked Sendable`: results are set by the test between loads; the call log is lock-guarded
/// because a ViewModel may call several methods concurrently.
final class MockProductRepository: ProductRepository, @unchecked Sendable {
    var featuredResult: Result<[Product], Error> = .success([])
    var allProductsResult: Result<[Product], Error> = .success([])
    var categoriesResult: Result<[ProductCategory], Error> = .success([])
    var categoryProductsResult: Result<CategoryProducts, Error> = .failure(MockError.notStubbed)
    var searchResult: Result<[Product], Error> = .success([])
    var productResult: Result<Product, Error> = .failure(MockError.notStubbed)

    private let callLog = Locked<[String]>([])
    var calls: [String] { callLog.withLock { $0 } }

    private func record(_ call: String) {
        callLog.withLock { $0.append(call) }
    }

    func featuredProducts() async throws -> [Product] {
        record("featuredProducts")
        return try featuredResult.get()
    }

    func allProducts() async throws -> [Product] {
        record("allProducts")
        return try allProductsResult.get()
    }

    func categories() async throws -> [ProductCategory] {
        record("categories")
        return try categoriesResult.get()
    }

    func categoryProducts(categoryID: String) async throws -> CategoryProducts {
        record("categoryProducts:\(categoryID)")
        return try categoryProductsResult.get()
    }

    func searchProducts(matching query: String) async throws -> [Product] {
        record("searchProducts:\(query)")
        return try searchResult.get()
    }

    func product(id: String) async throws -> Product {
        record("product:\(id)")
        return try productResult.get()
    }
}

final class MockEnquiryRepository: EnquiryRepository, @unchecked Sendable {
    var result: Result<EnquiryConfirmation, Error> = .success(EnquiryConfirmation(enquiryId: "e1", status: "sent"))
    private let submissionLog = Locked<[EnquiryRequest]>([])
    var submitted: [EnquiryRequest] { submissionLog.withLock { $0 } }

    func submit(_ enquiry: EnquiryRequest) async throws -> EnquiryConfirmation {
        submissionLog.withLock { $0.append(enquiry) }
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
