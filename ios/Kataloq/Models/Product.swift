import Foundation

/// A catalogue product as returned by kataloq-api (never decoded from Fake Store directly).
struct Product: Equatable, Hashable, Sendable, Identifiable {
    let id: String
    let title: String
    let description: String
    let price: Price
    let category: ProductCategory
    /// Absolute https URL of the product image, or nil (the UI shows a placeholder).
    /// The app loads image bytes directly from this host; product *data* always comes from our backend.
    let imageURL: URL?
    let rating: Rating
}

struct Price: Decodable, Equatable, Hashable, Sendable {
    /// Decimal, not Double, so money never suffers binary floating-point rounding.
    let amount: Decimal
    /// ISO 4217 code, e.g. "USD".
    let currency: String
}

struct Rating: Decodable, Equatable, Hashable, Sendable {
    /// 0–5.
    let average: Double
    let count: Int
}

/// Named `ProductCategory` rather than `Category` to avoid clashing with the Objective-C runtime's `Category` type.
struct ProductCategory: Decodable, Equatable, Hashable, Sendable, Identifiable {
    /// URL-safe slug, e.g. "mens-clothing".
    let id: String
    /// Display name, e.g. "Men's Clothing".
    let name: String
}

// Decoding lives in an extension so the memberwise initialiser stays available (tests, previews).
extension Product: Decodable {
    private enum CodingKeys: String, CodingKey {
        case id, title, description, price, category, rating
        case imageURL = "imageUrl"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        price = try container.decode(Price.self, forKey: .price)
        category = try container.decode(ProductCategory.self, forKey: .category)
        rating = try container.decode(Rating.self, forKey: .rating)

        // A missing, null or malformed image URL must not fail the whole product (or the whole list).
        let rawImageURL = try? container.decodeIfPresent(String.self, forKey: .imageURL)
        imageURL = rawImageURL.flatMap(Product.httpsURL(from:))
    }

    private static func httpsURL(from string: String) -> URL? {
        guard let url = URL(string: string), url.scheme?.lowercased() == "https", url.host != nil else { return nil }
        return url
    }
}
