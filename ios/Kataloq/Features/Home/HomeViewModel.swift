import Foundation

struct HomeContent: Equatable {
    let categories: [ProductCategory]
    let featured: [ProductCardViewData]
}

/// Home screen logic: loads the curated featured products and the category list.
/// No UIKit import: state and intents only, so it's fully unit-testable.
@MainActor
final class HomeViewModel {
    let title = "Kataloq"

    private(set) var state: LoadState<HomeContent> = .idle {
        didSet { onStateChange?(state) }
    }

    // Output to the view.
    var onStateChange: ((LoadState<HomeContent>) -> Void)?

    // Navigation intents, handled by the coordinator.
    var onProductSelected: ((String) -> Void)?
    var onCategorySelected: ((ProductCategory) -> Void)?
    var onSearchRequested: (() -> Void)?

    private let repository: any ProductRepository
    private let locale: Locale

    init(repository: any ProductRepository, locale: Locale = .current) {
        self.repository = repository
        self.locale = locale
    }

    /// Loads featured products and categories in parallel. Either failing shows the error state
    /// (both come from the same backend, so a partial screen would be misleading).
    func load() async {
        state = .loading
        let repository = self.repository
        do {
            async let featuredRequest = repository.featuredProducts()
            async let categoriesRequest = repository.categories()
            let (featured, categories) = try await (featuredRequest, categoriesRequest)

            // A newer load or the screen going away cancelled this one: leave the state alone.
            guard !Task.isCancelled else { return }

            if featured.isEmpty && categories.isEmpty {
                state = .empty(message: "No products to show right now. Please check back soon.")
            } else {
                state = .loaded(HomeContent(
                    categories: categories,
                    featured: featured.uniquedByID().map { ProductCardViewData(product: $0, locale: locale) }
                ))
            }
        } catch is CancellationError {
            return
        } catch {
            state = .failed(message: UserFacingError.message(for: error))
        }
    }

    func selectProduct(id: String) {
        onProductSelected?(id)
    }

    func selectCategory(_ category: ProductCategory) {
        onCategorySelected?(category)
    }

    func requestSearch() {
        onSearchRequested?()
    }
}
