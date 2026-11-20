import Foundation
@testable import Kataloq

enum Fixtures {
    static let electronics = ProductCategory(id: "electronics", name: "Electronics")
    static let jewelery = ProductCategory(id: "jewelery", name: "Jewelery")
    static let mensClothing = ProductCategory(id: "mens-clothing", name: "Men's Clothing")

    static let usLocale = Locale(identifier: "en_US")

    static func product(
        id: String = "1",
        title: String = "Product",
        amount: Decimal = 10,
        currency: String = "USD",
        category: ProductCategory = electronics,
        imageURL: URL? = nil,
        average: Double = 4,
        count: Int = 10
    ) -> Product {
        Product(
            id: id,
            title: title,
            description: "Description of \(title)",
            price: Price(amount: amount, currency: currency),
            category: category,
            imageURL: imageURL,
            rating: Rating(average: average, count: count)
        )
    }

    /// A product exactly as kataloq-api serialises it.
    static let productJSON = """
    {
      "id": "1",
      "title": "Fjallraven - Foldsack No. 1 Backpack",
      "description": "Your perfect pack for everyday use.",
      "price": { "amount": 109.95, "currency": "USD" },
      "category": { "id": "mens-clothing", "name": "Men's Clothing" },
      "imageUrl": "https://fakestoreapi.com/img/81fPKd-2AYL._AC_SL1500_t.png",
      "rating": { "average": 3.9, "count": 120 }
    }
    """

    static func productJSON(id: String, imageURL: String?) -> String {
        let image = imageURL.map { "\"\($0)\"" } ?? "null"
        return """
        {"id":"\(id)","title":"Item \(id)","description":"d","price":{"amount":1,"currency":"USD"},\
        "category":{"id":"electronics","name":"Electronics"},"imageUrl":\(image),"rating":{"average":4,"count":1}}
        """
    }

    static func data(_ json: String) -> Data {
        Data(json.utf8)
    }
}
