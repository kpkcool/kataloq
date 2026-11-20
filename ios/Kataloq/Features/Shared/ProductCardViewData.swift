import Foundation

/// The product card's configuration: what a card shows, already formatted. Built by ViewModels
/// so formatting is unit-testable and views only assign text. The presentation style is not
/// stored here, because the same product can appear as a featured and as a standard card.
struct ProductCardViewData: Hashable, Sendable {
    let id: String
    let title: String
    let priceText: String
    let ratingText: String
    /// "4.6" and "(400)", shown next to a star icon.
    let ratingScoreText: String
    let ratingCountText: String
    /// False when there are no ratings: the card shows "No ratings yet" instead.
    let isRated: Bool
    let imageURL: URL?
    /// One VoiceOver phrase for the whole tile.
    let accessibilityLabel: String

    init(product: Product, locale: Locale = .current) {
        id = product.id
        title = product.title
        priceText = ProductFormatting.price(product.price, locale: locale)
        ratingText = ProductFormatting.rating(product.rating, locale: locale)
        ratingScoreText = ProductFormatting.ratingScore(product.rating, locale: locale)
        ratingCountText = ProductFormatting.ratingCount(product.rating, locale: locale)
        isRated = product.rating.count > 0
        imageURL = product.imageURL
        accessibilityLabel = [
            product.title,
            priceText,
            ProductFormatting.ratingAccessibility(product.rating, locale: locale),
        ].joined(separator: ", ")
    }
}
