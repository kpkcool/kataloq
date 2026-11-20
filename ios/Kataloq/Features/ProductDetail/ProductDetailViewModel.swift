import Foundation

struct ProductDetailContent: Equatable {
    let title: String
    let description: String
    let categoryName: String
    let priceText: String
    let ratingText: String
    let ratingScoreText: String
    let ratingCountText: String
    let isRated: Bool
    let ratingAccessibilityText: String
    let imageURL: URL?
}

/// Product detail logic (FR-5). Fetches the product by ID (AS-5), so the screen works the same
/// from Home, Category, Search, or a future deep link.
@MainActor
final class ProductDetailViewModel {
    let enquireButtonTitle = "Enquire about this product"

    private(set) var state: LoadState<ProductDetailContent> = .idle {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((LoadState<ProductDetailContent>) -> Void)?
    /// Navigation intent: the user wants to enquire about the loaded product.
    var onEnquireRequested: ((Product) -> Void)?

    private let productID: String
    private let repository: any ProductRepository
    private let locale: Locale
    private var product: Product?

    init(productID: String, repository: any ProductRepository, locale: Locale = .current) {
        self.productID = productID
        self.repository = repository
        self.locale = locale
    }

    func load() async {
        state = .loading
        do {
            let product = try await repository.product(id: productID)
            guard !Task.isCancelled else { return }

            self.product = product
            state = .loaded(ProductDetailContent(
                title: product.title,
                description: product.description,
                categoryName: product.category.name,
                priceText: ProductFormatting.price(product.price, locale: locale),
                ratingText: ProductFormatting.rating(product.rating, locale: locale),
                ratingScoreText: ProductFormatting.ratingScore(product.rating, locale: locale),
                ratingCountText: ProductFormatting.ratingCount(product.rating, locale: locale),
                isRated: product.rating.count > 0,
                ratingAccessibilityText: ProductFormatting.ratingAccessibility(product.rating, locale: locale),
                imageURL: product.imageURL
            ))
        } catch is CancellationError {
            return
        } catch {
            state = .failed(message: UserFacingError.message(for: error))
        }
    }

    /// Only possible once the product has loaded (the button isn't shown before that).
    func requestEnquiry() {
        guard let product else { return }
        onEnquireRequested?(product)
    }
}
