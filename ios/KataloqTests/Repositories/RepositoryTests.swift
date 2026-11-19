import XCTest
@testable import Kataloq

final class RemoteProductRepositoryTests: XCTestCase {
    private func makeSUT(responseJSON: String) -> (RemoteProductRepository, MockAPIClient) {
        let client = MockAPIClient()
        client.responseJSON = responseJSON
        return (RemoteProductRepository(apiClient: client), client)
    }

    func testFeaturedProductsCallsFeaturedEndpointAndUnwrapsProducts() async throws {
        let (sut, client) = makeSUT(responseJSON: #"{"products":[\#(Fixtures.productJSON(id: "5", imageURL: nil))]}"#)

        let products = try await sut.featuredProducts()

        XCTAssertEqual(client.requestedEndpoints, [.get("/api/v1/products/featured")])
        XCTAssertEqual(products.map(\.id), ["5"])
    }

    func testCategoriesCallsCategoriesEndpoint() async throws {
        let (sut, client) = makeSUT(responseJSON: #"{"categories":[{"id":"electronics","name":"Electronics"}]}"#)

        let categories = try await sut.categories()

        XCTAssertEqual(client.requestedEndpoints, [.get("/api/v1/categories")])
        XCTAssertEqual(categories, [Fixtures.electronics])
    }

    func testCategoryProductsCallsCategoryEndpoint() async throws {
        let (sut, client) = makeSUT(responseJSON: #"{"category":{"id":"electronics","name":"Electronics"},"topRated":[],"additional":[]}"#)

        let page = try await sut.categoryProducts(categoryID: "electronics")

        XCTAssertEqual(client.requestedEndpoints, [.get("/api/v1/categories/electronics/products")])
        XCTAssertEqual(page.category, Fixtures.electronics)
    }

    func testSearchSendsTheQueryAsTheQParameter() async throws {
        let (sut, client) = makeSUT(responseJSON: #"{"query":"jacket","products":[]}"#)

        _ = try await sut.searchProducts(matching: "jacket")

        XCTAssertEqual(client.requestedEndpoints, [.get("/api/v1/products/search", queryItems: [URLQueryItem(name: "q", value: "jacket")])])
    }

    func testProductCallsProductEndpointAndUnwrapsProduct() async throws {
        let (sut, client) = makeSUT(responseJSON: #"{"product":\#(Fixtures.productJSON(id: "9", imageURL: nil))}"#)

        let product = try await sut.product(id: "9")

        XCTAssertEqual(client.requestedEndpoints, [.get("/api/v1/products/9")])
        XCTAssertEqual(product.id, "9")
    }

    func testPropagatesClientErrors() async {
        let (sut, client) = makeSUT(responseJSON: "{}")
        client.error = APIError.timeout

        await assertThrowsAsync({ try await sut.featuredProducts() }) { error in
            XCTAssertEqual(error as? APIError, .timeout)
        }
    }
}

final class RemoteEnquiryRepositoryTests: XCTestCase {
    func testSubmitPostsTheEnquiryAsJSON() async throws {
        let client = MockAPIClient()
        client.responseJSON = #"{"enquiryId":"e1","status":"sent"}"#
        let sut = RemoteEnquiryRepository(apiClient: client)
        let enquiry = EnquiryRequest(productId: "1", name: "Jane", email: "jane@example.com", phone: "0400 000 000", message: nil)

        let confirmation = try await sut.submit(enquiry)

        XCTAssertEqual(confirmation, EnquiryConfirmation(enquiryId: "e1", status: "sent"))
        let endpoint = try XCTUnwrap(client.requestedEndpoints.first)
        XCTAssertEqual(endpoint.method, .post)
        XCTAssertEqual(endpoint.path, "/api/v1/enquiries")
        XCTAssertEqual(endpoint.body, try JSONEncoder().encode(enquiry))
    }
}
