import Foundation

/// Product data for the screens. ViewModels depend on this protocol, so they're tested with a mock.
protocol ProductRepository: Sendable {
    func featuredProducts() async throws -> [Product]
    func categories() async throws -> [ProductCategory]
    func categoryProducts(categoryID: String) async throws -> CategoryProducts
    func searchProducts(matching query: String) async throws -> [Product]
    func product(id: String) async throws -> Product
}

/// Reads products from kataloq-api. The only place that knows the catalogue endpoint paths.
final class RemoteProductRepository: ProductRepository {
    private let apiClient: any APIClient

    init(apiClient: any APIClient) {
        self.apiClient = apiClient
    }

    func featuredProducts() async throws -> [Product] {
        try await apiClient.send(.get("/api/v1/products/featured"), as: FeaturedProductsResponse.self).products
    }

    func categories() async throws -> [ProductCategory] {
        try await apiClient.send(.get("/api/v1/categories"), as: CategoriesResponse.self).categories
    }

    func categoryProducts(categoryID: String) async throws -> CategoryProducts {
        try await apiClient.send(.get("/api/v1/categories/\(categoryID)/products"), as: CategoryProducts.self)
    }

    func searchProducts(matching query: String) async throws -> [Product] {
        let endpoint = Endpoint.get("/api/v1/products/search", queryItems: [URLQueryItem(name: "q", value: query)])
        return try await apiClient.send(endpoint, as: SearchResponse.self).products
    }

    func product(id: String) async throws -> Product {
        try await apiClient.send(.get("/api/v1/products/\(id)"), as: ProductResponse.self).product
    }
}
