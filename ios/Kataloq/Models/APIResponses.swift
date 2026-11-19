import Foundation

// Response envelopes of kataloq-api (docs/ARCHITECTURE.md §4). Property names match the
// JSON keys exactly (camelCase), so no CodingKeys or key strategies are needed.

struct FeaturedProductsResponse: Decodable {
    let products: [Product]
}

struct CategoriesResponse: Decodable {
    let categories: [ProductCategory]
}

/// A category page: the backend has already ranked the products and split them, without overlap.
struct CategoryProducts: Decodable, Equatable, Sendable {
    let category: ProductCategory
    /// "Top Rated" section.
    let topRated: [Product]
    /// "All Products" section: the remaining products, same ranked order.
    let additional: [Product]
}

struct SearchResponse: Decodable {
    let query: String
    let products: [Product]
}

struct ProductResponse: Decodable {
    let product: Product
}

/// The error body every kataloq-api error uses: `{ "error": { code, message, requestId, details? } }`.
struct APIErrorResponse: Decodable, Equatable {
    struct Body: Decodable, Equatable {
        let code: String
        /// Safe to show to the user.
        let message: String
        let requestId: String?
        let details: [FieldError]?
    }

    let error: Body
}

struct FieldError: Decodable, Equatable, Hashable, Sendable {
    let field: String
    let message: String
}
