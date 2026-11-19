import XCTest
@testable import Kataloq

@MainActor
final class ProductDetailViewModelTests: XCTestCase {
    private let backpack = Fixtures.product(
        id: "1",
        title: "Fjallraven Backpack",
        amount: 109.95,
        category: Fixtures.mensClothing,
        imageURL: URL(string: "https://images.test/1.png"),
        average: 3.9,
        count: 120
    )

    private func makeSUT(result: Result<Product, Error>) -> (ProductDetailViewModel, MockProductRepository) {
        let repository = MockProductRepository()
        repository.productResult = result
        let sut = ProductDetailViewModel(productID: "1", repository: repository, locale: Fixtures.usLocale)
        trackForMemoryLeaks(sut)
        return (sut, repository)
    }

    func testLoadFetchesTheProductByID() async {
        let (sut, repository) = makeSUT(result: .success(backpack))

        await sut.load()

        XCTAssertEqual(repository.calls, ["product:1"])
    }

    func testShowsEveryDetailFieldFormatted() async {
        let (sut, _) = makeSUT(result: .success(backpack))
        var states: [LoadState<ProductDetailContent>] = []
        sut.onStateChange = { states.append($0) }

        await sut.load()

        XCTAssertEqual(states.first, .loading)
        XCTAssertEqual(sut.state, .loaded(ProductDetailContent(
            title: "Fjallraven Backpack",
            description: "Description of Fjallraven Backpack",
            categoryName: "Men's Clothing",
            priceText: "$109.95",
            ratingText: "★ 3.9 (120)",
            ratingAccessibilityText: "Rated 3.9 out of 5 from 120 reviews",
            imageURL: URL(string: "https://images.test/1.png")
        )))
    }

    func testUnknownProductShowsTheBackendMessage() async {
        let notFound = APIError.server(status: 404, code: "PRODUCT_NOT_FOUND", message: "Product not found.", fieldErrors: [])
        let (sut, _) = makeSUT(result: .failure(notFound))

        await sut.load()

        XCTAssertEqual(sut.state, .failed(message: "Product not found."))
    }

    func testRetryAfterFailureLoadsTheProduct() async {
        let (sut, repository) = makeSUT(result: .failure(APIError.timeout))
        await sut.load()

        repository.productResult = .success(backpack)
        await sut.load()

        guard case .loaded(let content) = sut.state else { return XCTFail("Expected loaded, got \(sut.state)") }
        XCTAssertEqual(content.title, "Fjallraven Backpack")
    }

    func testCancellationDoesNotShowAnError() async {
        let (sut, _) = makeSUT(result: .failure(CancellationError()))

        await sut.load()

        XCTAssertEqual(sut.state, .loading)
    }

    func testEnquireForwardsTheLoadedProduct() async {
        let (sut, _) = makeSUT(result: .success(backpack))
        var requested: Product?
        sut.onEnquireRequested = { requested = $0 }
        await sut.load()

        sut.requestEnquiry()

        XCTAssertEqual(requested, backpack)
    }

    func testEnquireDoesNothingBeforeTheProductHasLoaded() {
        let (sut, _) = makeSUT(result: .success(backpack))
        var requested: Product?
        sut.onEnquireRequested = { requested = $0 }

        sut.requestEnquiry()

        XCTAssertNil(requested)
    }
}
