import XCTest
@testable import Kataloq

final class ModelDecodingTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testDecodesProductFromBackendContract() throws {
        let product = try decoder.decode(Product.self, from: Fixtures.data(Fixtures.productJSON))

        XCTAssertEqual(product.id, "1")
        XCTAssertEqual(product.title, "Fjallraven - Foldsack No. 1 Backpack")
        XCTAssertEqual(product.description, "Your perfect pack for everyday use.")
        XCTAssertEqual(NSDecimalNumber(decimal: product.price.amount).doubleValue, 109.95, accuracy: 0.0001)
        XCTAssertEqual(product.price.currency, "USD")
        XCTAssertEqual(product.category, Fixtures.mensClothing)
        XCTAssertEqual(product.imageURL?.absoluteString, "https://fakestoreapi.com/img/81fPKd-2AYL._AC_SL1500_t.png")
        XCTAssertEqual(product.rating, Rating(average: 3.9, count: 120))
    }

    func testNullImageURLDecodesToNil() throws {
        let product = try decoder.decode(Product.self, from: Fixtures.data(Fixtures.productJSON(id: "1", imageURL: nil)))
        XCTAssertNil(product.imageURL)
    }

    func testInvalidOrInsecureImageURLDecodesToNilWithoutFailingTheProduct() throws {
        for imageURL in ["", "not a url", "http://insecure.example.com/a.png", "/relative/path.png"] {
            let product = try decoder.decode(Product.self, from: Fixtures.data(Fixtures.productJSON(id: "1", imageURL: imageURL)))
            XCTAssertNil(product.imageURL, "Expected nil for \(imageURL)")
        }
    }

    func testMissingImageURLKeyDecodesToNil() throws {
        let json = """
        {"id":"1","title":"t","description":"d","price":{"amount":1,"currency":"USD"},
         "category":{"id":"electronics","name":"Electronics"},"rating":{"average":4,"count":1}}
        """
        XCTAssertNil(try decoder.decode(Product.self, from: Fixtures.data(json)).imageURL)
    }

    func testMissingRequiredFieldFailsDecoding() {
        let json = #"{"id":"1","title":"t"}"#
        XCTAssertThrowsError(try decoder.decode(Product.self, from: Fixtures.data(json)))
    }

    func testDecodesCategoryProducts() throws {
        let json = """
        {"category":{"id":"electronics","name":"Electronics"},
         "topRated":[\(Fixtures.productJSON(id: "12", imageURL: nil)),\(Fixtures.productJSON(id: "11", imageURL: nil))],
         "additional":[\(Fixtures.productJSON(id: "9", imageURL: nil))]}
        """
        let page = try decoder.decode(CategoryProducts.self, from: Fixtures.data(json))

        XCTAssertEqual(page.category, Fixtures.electronics)
        XCTAssertEqual(page.topRated.map(\.id), ["12", "11"])
        XCTAssertEqual(page.additional.map(\.id), ["9"])
    }

    func testDecodesErrorBodyWithFieldDetails() throws {
        let json = """
        {"error":{"code":"VALIDATION_ERROR","message":"Some fields are invalid.","requestId":"r1",
          "details":[{"field":"email","message":"Enter a valid email address."}]}}
        """
        let body = try decoder.decode(APIErrorResponse.self, from: Fixtures.data(json))

        XCTAssertEqual(body.error.code, "VALIDATION_ERROR")
        XCTAssertEqual(body.error.requestId, "r1")
        XCTAssertEqual(body.error.details, [FieldError(field: "email", message: "Enter a valid email address.")])
    }

    func testEnquiryRequestOmitsNilOptionalFields() throws {
        let request = EnquiryRequest(productId: "1", name: "Jane", email: "jane@example.com", phone: nil, message: nil)

        let data = try JSONEncoder().encode(request)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(Set(object.keys), ["productId", "name", "email"])
    }
}
