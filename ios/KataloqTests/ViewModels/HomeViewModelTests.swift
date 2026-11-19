import XCTest
@testable import Kataloq

@MainActor
final class HomeViewModelTests: XCTestCase {
    private func makeSUT(
        featured: Result<[Product], Error> = .success([]),
        categories: Result<[ProductCategory], Error> = .success([])
    ) -> (HomeViewModel, MockProductRepository, StateRecorder) {
        let repository = MockProductRepository()
        repository.featuredResult = featured
        repository.categoriesResult = categories
        let sut = HomeViewModel(repository: repository, locale: Fixtures.usLocale)
        let recorder = StateRecorder()
        sut.onStateChange = { recorder.states.append($0) }
        trackForMemoryLeaks(sut)
        return (sut, repository, recorder)
    }

    func testStartsIdle() {
        let (sut, _, _) = makeSUT()
        XCTAssertEqual(sut.state, .idle)
    }

    func testLoadShowsLoadingThenFeaturedProductsAndCategories() async {
        let backpack = Fixtures.product(id: "1", title: "Backpack", amount: 109.95, average: 3.9, count: 120)
        let (sut, repository, recorder) = makeSUT(
            featured: .success([backpack, Fixtures.product(id: "5")]),
            categories: .success([Fixtures.electronics, Fixtures.jewelery])
        )

        await sut.load()

        XCTAssertEqual(recorder.states.first, .loading)
        guard case .loaded(let content) = sut.state else { return XCTFail("Expected loaded, got \(sut.state)") }
        XCTAssertEqual(content.categories, [Fixtures.electronics, Fixtures.jewelery])
        XCTAssertEqual(content.featured.map(\.id), ["1", "5"], "Keeps the backend's configured order")
        XCTAssertEqual(content.featured.first?.priceText, "$109.95")
        XCTAssertEqual(content.featured.first?.ratingText, "★ 3.9 (120)")
        XCTAssertEqual(Set(repository.calls), ["featuredProducts", "categories"])
    }

    func testFeaturedEmptyButCategoriesPresentIsStillLoaded() async {
        let (sut, _, _) = makeSUT(categories: .success([Fixtures.electronics]))

        await sut.load()

        XCTAssertEqual(sut.state, .loaded(HomeContent(categories: [Fixtures.electronics], featured: [])))
    }

    func testNothingToShowIsEmptyState() async {
        let (sut, _, _) = makeSUT()

        await sut.load()

        XCTAssertEqual(sut.state, .empty(message: "No products to show right now. Please check back soon."))
    }

    func testBackendErrorShowsTheBackendMessage() async {
        let error = APIError.server(
            status: 502, code: "UPSTREAM_UNAVAILABLE",
            message: "Product data is temporarily unavailable. Please try again.", fieldErrors: []
        )
        let (sut, _, _) = makeSUT(featured: .failure(error))

        await sut.load()

        XCTAssertEqual(sut.state, .failed(message: "Product data is temporarily unavailable. Please try again."))
    }

    func testBackendNotRunningShowsConnectionMessage() async {
        let (sut, _, _) = makeSUT(categories: .failure(APIError.transport(.cannotConnectToHost)))

        await sut.load()

        XCTAssertEqual(sut.state, .failed(message: "Can't reach Kataloq right now. Please try again."))
    }

    func testRetryAfterFailureLoadsContent() async {
        let (sut, repository, _) = makeSUT(featured: .failure(APIError.timeout))
        await sut.load()
        XCTAssertEqual(sut.state, .failed(message: "This is taking longer than expected. Please try again."))

        repository.featuredResult = .success([Fixtures.product(id: "1")])
        await sut.load()

        guard case .loaded(let content) = sut.state else { return XCTFail("Expected loaded, got \(sut.state)") }
        XCTAssertEqual(content.featured.map(\.id), ["1"])
    }

    func testCancellationDoesNotShowAnError() async {
        let (sut, _, recorder) = makeSUT(featured: .failure(CancellationError()))

        await sut.load()

        XCTAssertEqual(recorder.states, [.loading])
    }

    func testSelectionsAreForwardedAsNavigationIntents() {
        let (sut, _, _) = makeSUT()
        var selectedProduct: String?
        var selectedCategory: ProductCategory?
        var searchRequested = false
        sut.onProductSelected = { selectedProduct = $0 }
        sut.onCategorySelected = { selectedCategory = $0 }
        sut.onSearchRequested = { searchRequested = true }

        sut.selectProduct(id: "9")
        sut.selectCategory(Fixtures.jewelery)
        sut.requestSearch()

        XCTAssertEqual(selectedProduct, "9")
        XCTAssertEqual(selectedCategory, Fixtures.jewelery)
        XCTAssertTrue(searchRequested)
    }
}

/// Collects every state a ViewModel publishes, in order.
@MainActor
final class StateRecorder {
    var states: [LoadState<HomeContent>] = []
}
