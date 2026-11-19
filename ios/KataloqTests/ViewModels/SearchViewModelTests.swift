import XCTest
@testable import Kataloq

@MainActor
final class SearchViewModelTests: XCTestCase {
    private func makeSUT(result: Result<[Product], Error> = .success([])) -> (SearchViewModel, MockProductRepository) {
        let repository = MockProductRepository()
        repository.searchResult = result
        let sut = SearchViewModel(repository: repository, locale: Fixtures.usLocale)
        trackForMemoryLeaks(sut)
        return (sut, repository)
    }

    func testStartsWithThePrompt() {
        let (sut, _) = makeSUT()
        XCTAssertEqual(sut.state, .idle)
    }

    func testBlankQueryIsRejectedWithoutCallingTheBackend() async {
        let (sut, repository) = makeSUT()

        for blank in ["", "   ", "\n\t"] {
            await sut.search(blank)
            XCTAssertEqual(sut.state, .invalidQuery(message: "Enter a product name, description or category to search."))
        }
        XCTAssertTrue(repository.calls.isEmpty)
    }

    func testOverLongQueryIsRejectedWithoutCallingTheBackend() async {
        let (sut, repository) = makeSUT()

        await sut.search(String(repeating: "x", count: 101))

        XCTAssertEqual(sut.state, .invalidQuery(message: "Search terms can be at most 100 characters."))
        XCTAssertTrue(repository.calls.isEmpty)
    }

    func testAcceptsAQueryOfExactlyTheMaximumLength() async {
        let (sut, repository) = makeSUT()

        await sut.search(String(repeating: "x", count: 100))

        XCTAssertEqual(repository.calls.count, 1)
    }

    func testSearchSendsTheTrimmedQueryAndShowsResultsInBackendOrder() async {
        let (sut, repository) = makeSUT(result: .success([
            Fixtures.product(id: "3", title: "Mens Cotton Jacket"),
            Fixtures.product(id: "15", title: "Winter Jacket"),
        ]))
        var states: [SearchState] = []
        sut.onStateChange = { states.append($0) }

        await sut.search("  jacket ")

        XCTAssertEqual(repository.calls, ["searchProducts:jacket"])
        XCTAssertEqual(states.first, .loading(query: "jacket"))
        guard case .results(let results) = sut.state else { return XCTFail("Expected results, got \(sut.state)") }
        XCTAssertEqual(results.query, "jacket")
        XCTAssertEqual(results.products.map(\.id), ["3", "15"])
        XCTAssertEqual(results.title, "2 results for \u{201C}jacket\u{201D}")
    }

    func testSingleResultTitleIsSingular() {
        let results = SearchResults(query: "ssd", products: [ProductCardViewData(product: Fixtures.product(), locale: Fixtures.usLocale)])
        XCTAssertEqual(results.title, "1 result for \u{201C}ssd\u{201D}")
    }

    func testNoMatchesShowsNoResultsForThatQuery() async {
        let (sut, _) = makeSUT(result: .success([]))

        await sut.search("unicorn")

        XCTAssertEqual(sut.state, .noResults(query: "unicorn"))
    }

    func testFailureShowsTheErrorAndRetryRepeatsTheLastQuery() async {
        let (sut, repository) = makeSUT(result: .failure(APIError.transport(.cannotConnectToHost)))
        await sut.search("shirt")
        XCTAssertEqual(sut.state, .failed(query: "shirt", message: "Can't reach Kataloq right now. Please try again."))

        repository.searchResult = .success([Fixtures.product(id: "2")])
        sut.retry()
        await sut.searchTask?.value

        XCTAssertEqual(repository.calls, ["searchProducts:shirt", "searchProducts:shirt"])
        guard case .results(let results) = sut.state else { return XCTFail("Expected results, got \(sut.state)") }
        XCTAssertEqual(results.products.map(\.id), ["2"])
    }

    func testANewSearchCancelsThePreviousOne() async {
        let (sut, repository) = makeSUT(result: .success([Fixtures.product(id: "1")]))

        sut.submitSearch("first")
        sut.submitSearch("second")
        await sut.searchTask?.value

        XCTAssertEqual(repository.calls, ["searchProducts:second"])
        guard case .results(let results) = sut.state else { return XCTFail("Expected results, got \(sut.state)") }
        XCTAssertEqual(results.query, "second")
    }

    func testCancellationDoesNotShowAnError() async {
        let (sut, _) = makeSUT(result: .failure(CancellationError()))

        await sut.search("shirt")

        XCTAssertEqual(sut.state, .loading(query: "shirt"))
    }

    func testClearReturnsToThePrompt() async {
        let (sut, _) = makeSUT(result: .success([Fixtures.product(id: "1")]))
        await sut.search("shirt")

        sut.clear()

        XCTAssertEqual(sut.state, .idle)
    }

    func testSelectingAResultForwardsItsID() {
        let (sut, _) = makeSUT()
        var selected: String?
        sut.onProductSelected = { selected = $0 }

        sut.selectProduct(id: "3")

        XCTAssertEqual(selected, "3")
    }
}
