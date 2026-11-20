import Foundation

/// Presentation text for prices and ratings, in one place so every screen shows them the same way.
enum ProductFormatting {
    /// "$109.95" (formatted for the given locale, using the product's own currency code).
    static func price(_ price: Price, locale: Locale = .current) -> String {
        price.amount.formatted(.currency(code: price.currency).locale(locale))
    }

    /// "★ 4.6 (400)", or "No ratings yet".
    static func rating(_ rating: Rating, locale: Locale = .current) -> String {
        guard rating.count > 0 else { return "No ratings yet" }
        return "★ \(ratingScore(rating, locale: locale)) \(ratingCount(rating, locale: locale))"
    }

    /// "4.6": the score on its own, for layouts that draw the star as an icon.
    static func ratingScore(_ rating: Rating, locale: Locale = .current) -> String {
        average(rating, locale: locale)
    }

    /// "(400)": the number of ratings, grouped for the locale ("(1,250)").
    static func ratingCount(_ rating: Rating, locale: Locale = .current) -> String {
        "(\(rating.count.formatted(.number.locale(locale))))"
    }

    /// "Rated 4.6 out of 5 from 400 reviews", for VoiceOver.
    static func ratingAccessibility(_ rating: Rating, locale: Locale = .current) -> String {
        guard rating.count > 0 else { return "No ratings yet" }
        let reviews = rating.count == 1 ? "1 review" : "\(rating.count) reviews"
        return "Rated \(average(rating, locale: locale)) out of 5 from \(reviews)"
    }

    private static func average(_ rating: Rating, locale: Locale) -> String {
        rating.average.formatted(.number.precision(.fractionLength(1)).locale(locale))
    }
}
