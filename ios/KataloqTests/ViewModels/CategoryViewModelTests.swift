import XCTest
@testable import Kataloq

@MainActor
final class CategoryViewModelTests: XCTestCase {
    private func makeSUT(
        category: ProductCategory = Fixtures.electronics,
        result: Result<CategoryProducts, Error>
    ) -> (CategoryViewModel, MockProductRepository) {
        let repository = MockProductRepository()
        repository.categoryProductsResult = result
        let sut = CategoryViewModel(category: category, repository: repository, locale: Fixtures.usLocale)
        trackForMemoryLeaks(sut)
        return (sut, repository)
    }

    private func page(topRated: [String], additional: [String]) -> CategoryProducts {
        CategoryProducts(
            category: Fixtures.electronics,
            topRated: topRated.map { Fixtures.product(id: $0) },
            additional: additional.map { Fixtures.product(id: $0) }
        )
    }

    func testTitleIsTheCategoryName() {
        let (sut, _) = makeSUT(category: Fixtures.mensClothing, result: .failure(MockError.notStubbed))
        XCTAssertEqual(sut.title, "Men's Clothing")
    }

    func testLoadRequestsTheSelectedCategory() async {
        let (sut, repository) = makeSUT(result: .success(page(topRated: ["12"], additional: [])))

        await sut.load()

        XCTAssertEqual(repository.calls, ["categoryProducts:electronics"])
    }

    func testShowsTopRatedAndAllProductsInTheBackendOrder() async {
        // Deliberately not in rating order: ranking is the backend's job, the app must not re-sort.
        let (sut, _) = makeSUT(result: .success(page(topRated: ["12", "11", "9"], additional: ["10", "13", "14"])))
        var states: [LoadState<CategoryContent>] = []
        sut.onStateChange = { states.append($0) }

        await sut.load()

        XCTAssertEqual(states.first, .loading)
        guard case .loaded(let content) = sut.state else { return XCTFail("Expected loaded, got \(sut.state)") }
        XCTAssertEqual(content.topRated.map(\.id), ["12", "11", "9"])
        XCTAssertEqual(content.allProducts.map(\.id), ["10", "13", "14"])
    }

    func testCategoryWithOnlyTopRatedProductsIsLoaded() async {
        let (sut, _) = makeSUT(result: .success(page(topRated: ["5", "6"], additional: [])))

        await sut.load()

        guard case .loaded(let content) = sut.state else { return XCTFail("Expected loaded, got \(sut.state)") }
        XCTAssertEqual(content.topRated.map(\.id), ["5", "6"])
        XCTAssertTrue(content.allProducts.isEmpty)
    }

    func testDuplicateProductsInAMalformedResponseAreDroppedInsteadOfCrashing() async {
        let (sut, _) = makeSUT(result: .success(page(topRated: ["1", "2", "2"], additional: ["2", "3", "3"])))

        await sut.load()

        guard case .loaded(let content) = sut.state else { return XCTFail("Expected loaded, got \(sut.state)") }
        XCTAssertEqual(content.topRated.map(\.id), ["1", "2"])
        XCTAssertEqual(content.allProducts.map(\.id), ["3"])
    }

    func testEmptyCategoryShowsEmptyState() async {
        let (sut, _) = makeSUT(result: .success(page(topRated: [], additional: [])))

        await sut.load()

        XCTAssertEqual(sut.state, .empty(message: "There are no products in Electronics yet."))
    }

    func testUnknownCategoryShowsTheBackendMessage() async {
        let notFound = APIError.server(status: 404, code: "CATEGORY_NOT_FOUND", message: "Category not found.", fieldErrors: [])
        let (sut, _) = makeSUT(result: .failure(notFound))

        await sut.load()

        XCTAssertEqual(sut.state, .failed(message: "Category not found."))
    }

    func testRetryAfterFailure() async {
        let (sut, repository) = makeSUT(result: .failure(APIError.transport(.cannotConnectToHost)))
        await sut.load()
        XCTAssertEqual(sut.state, .failed(message: "Can't reach Kataloq right now. Please try again."))

        repository.categoryProductsResult = .success(page(topRated: ["1"], additional: []))
        await sut.load()

        guard case .loaded = sut.state else { return XCTFail("Expected loaded, got \(sut.state)") }
    }

    func testCancellationDoesNotShowAnError() async {
        let (sut, _) = makeSUT(result: .failure(CancellationError()))

        await sut.load()

        XCTAssertEqual(sut.state, .loading)
    }

    func testSelectingAProductForwardsItsID() {
        let (sut, _) = makeSUT(result: .failure(MockError.notStubbed))
        var selected: String?
        sut.onProductSelected = { selected = $0 }

        sut.selectProduct(id: "11")

        XCTAssertEqual(selected, "11")
    }
}
