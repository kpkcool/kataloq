import Foundation

/// Search has more states than `LoadState` expresses (a prompt, an invalid query, "no results"
/// for a specific term), so it gets its own enum.
enum SearchState: Equatable {
    /// Nothing searched yet: show a prompt.
    case idle
    /// The user pressed Search with an empty or too-long term. No request was made.
    case invalidQuery(message: String)
    case loading(query: String)
    case results(SearchResults)
    case noResults(query: String)
    case failed(query: String, message: String)
}

struct SearchResults: Equatable {
    let query: String
    let products: [ProductCardViewData]

    /// "3 results for "shirt""
    var title: String {
        let noun = products.count == 1 ? "result" : "results"
        return "\(products.count) \(noun) for \u{201C}\(query)\u{201D}"
    }
}

/// Search logic (FR-4). Matching happens on the backend; this ViewModel validates the term,
/// runs one search at a time, and keeps the backend's result order.
///
/// Two triggers: typing (after a short pause, so "backpack" sends one request rather than eight)
/// and the keyboard's Search button (immediately).
@MainActor
final class SearchViewModel {
    /// Mirrors the backend limit, so the user gets instant feedback instead of a 400.
    static let maxQueryLength = 100

    private(set) var state: SearchState = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((SearchState) -> Void)?
    var onProductSelected: ((String) -> Void)?

    /// The in-flight search started by `submitSearch`. Internal so tests can await it.
    private(set) var searchTask: Task<Void, Never>?
    private var lastQuery: String?

    private let repository: any ProductRepository
    private let locale: Locale
    private let typingDelay: Duration

    init(repository: any ProductRepository, locale: Locale = .current, typingDelay: Duration = .milliseconds(300)) {
        self.repository = repository
        self.locale = locale
        self.typingDelay = typingDelay
    }

    deinit {
        searchTask?.cancel()
    }

    /// Called when the user taps the keyboard's Search button. Cancels any search still running,
    /// so a slow earlier response can never overwrite newer results.
    func submitSearch(_ text: String) {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            await self?.search(text)
        }
    }

    /// Called on every change to the search field. Waits `typingDelay` and then searches; each
    /// keystroke cancels the previous wait (and any search still running). An empty field
    /// returns to the prompt without calling the backend.
    func queryChanged(_ text: String) {
        searchTask?.cancel()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            clear()
            return
        }
        let delay = typingDelay
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.search(text)
        }
    }

    func retry() {
        guard let lastQuery else { return }
        submitSearch(lastQuery)
    }

    /// Called when the user cancels or clears the search field.
    func clear() {
        searchTask?.cancel()
        searchTask = nil
        lastQuery = nil
        state = .idle
    }

    func selectProduct(id: String) {
        onProductSelected?(id)
    }

    func search(_ text: String) async {
        guard !Task.isCancelled else { return }

        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            state = .invalidQuery(message: "Enter a product name, description or category to search.")
            return
        }
        guard query.count <= Self.maxQueryLength else {
            state = .invalidQuery(message: "Search terms can be at most \(Self.maxQueryLength) characters.")
            return
        }

        lastQuery = query
        state = .loading(query: query)
        do {
            let products = try await repository.searchProducts(matching: query)
            guard !Task.isCancelled else { return }

            if products.isEmpty {
                state = .noResults(query: query)
            } else {
                state = .results(SearchResults(
                    query: query,
                    products: products.uniquedByID().map { ProductCardViewData(product: $0, locale: locale) }
                ))
            }
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(query: query, message: UserFacingError.message(for: error))
        }
    }
}
