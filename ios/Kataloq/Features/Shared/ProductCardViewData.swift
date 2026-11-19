import Foundation

/// What a product tile shows. Built by ViewModels so formatting is unit-testable
/// and views only assign text.
struct ProductCardViewData: Hashable, Sendable {
    let id: String
    let title: String
    let priceText: String
    let ratingText: String
    let imageURL: URL?
    /// One VoiceOver phrase for the whole tile.
    let accessibilityLabel: String

    init(product: Product, locale: Locale = .current) {
        id = product.id
        title = product.title
        priceText = ProductFormatting.price(product.price, locale: locale)
        ratingText = ProductFormatting.rating(product.rating, locale: locale)
        imageURL = product.imageURL
        accessibilityLabel = [
            product.title,
            priceText,
            ProductFormatting.ratingAccessibility(product.rating, locale: locale),
        ].joined(separator: ", ")
    }
}
