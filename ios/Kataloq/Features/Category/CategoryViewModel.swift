import Foundation

struct CategoryContent: Equatable {
    /// "Top Rated": the backend's first N products by rating.
    let topRated: [ProductCardViewData]
    /// "All Products": the remaining products, same order, never repeating a top-rated one.
    let allProducts: [ProductCardViewData]
}

/// Category screen logic. Ranking, the top-3 split and de-duplication are backend rules (D7/D8),
/// so this ViewModel deliberately keeps the backend's order and sections as they are.
@MainActor
final class CategoryViewModel {
    let title: String

    private(set) var state: LoadState<CategoryContent> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((LoadState<CategoryContent>) -> Void)?
    var onProductSelected: ((String) -> Void)?

    private let category: ProductCategory
    private let repository: any ProductRepository
    private let locale: Locale

    init(category: ProductCategory, repository: any ProductRepository, locale: Locale = .current) {
        self.category = category
        self.repository = repository
        self.locale = locale
        title = category.name
    }

    func load() async {
        state = .loading
        do {
            let page = try await repository.categoryProducts(categoryID: category.id)
            guard !Task.isCancelled else { return }

            if page.topRated.isEmpty && page.additional.isEmpty {
                state = .empty(message: "There are no products in \(category.name) yet.")
            } else {
                // The backend never repeats a product across sections; guard anyway (see uniquedByID).
                let topRated = page.topRated.uniquedByID()
                let topRatedIDs = Set(topRated.map(\.id))
                let allProducts = page.additional.filter { !topRatedIDs.contains($0.id) }.uniquedByID()
                state = .loaded(CategoryContent(
                    topRated: topRated.map { ProductCardViewData(product: $0, locale: locale) },
                    allProducts: allProducts.map { ProductCardViewData(product: $0, locale: locale) }
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
}
