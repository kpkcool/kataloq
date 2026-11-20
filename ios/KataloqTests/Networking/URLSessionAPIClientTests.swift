import XCTest
@testable import Kataloq

final class URLSessionAPIClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocolStub.reset()
    }

    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    private func makeClient(baseURL: String = "http://localhost:3000") throws -> URLSessionAPIClient {
        URLSessionAPIClient(baseURL: try XCTUnwrap(URL(string: baseURL)), session: URLProtocolStub.makeSession())
    }

    private func stub(status: Int, json: String) {
        URLProtocolStub.stub = .init(data: Data(json.utf8), statusCode: status)
    }

    private func stub(error: URLError.Code) {
        URLProtocolStub.stub = .init(error: URLError(error))
    }

    // MARK: - Requests

    func testGETBuildsURLFromBasePathAndPercentEncodesQueryValues() async throws {
        stub(status: 200, json: #"{"query":"c++ & tea","products":[]}"#)
        let client = try makeClient()

        _ = try await client.send(
            .get("/api/v1/products/search", queryItems: [URLQueryItem(name: "q", value: "c++ & tea")]),
            as: SearchResponse.self
        )

        let request = try XCTUnwrap(URLProtocolStub.capturedRequests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        // "+" and "&" must be escaped, or the server reads "c  " and a second parameter.
        XCTAssertEqual(request.url?.absoluteString, "http://localhost:3000/api/v1/products/search?q=c%2B%2B%20%26%20tea")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertNil(request.httpBody)
    }

    func testKeepsAPathPrefixInTheBaseURL() async throws {
        stub(status: 200, json: #"{"categories":[]}"#)
        let client = try makeClient(baseURL: "https://api.example.com/kataloq/")

        _ = try await client.send(.get("/api/v1/categories"), as: CategoriesResponse.self)

        XCTAssertEqual(URLProtocolStub.capturedRequests.first?.url?.absoluteString, "https://api.example.com/kataloq/api/v1/categories")
    }

    func testPOSTSendsJSONBodyAndDecodesTheResponse() async throws {
        stub(status: 202, json: #"{"enquiryId":"e1","status":"sent"}"#)
        let client = try makeClient()
        let enquiry = EnquiryRequest(productId: "1", name: "Jane", email: "jane@example.com", phone: nil, message: "Hi")

        let confirmation = try await client.send(try .post("/api/v1/enquiries", body: enquiry), as: EnquiryConfirmation.self)

        XCTAssertEqual(confirmation, EnquiryConfirmation(enquiryId: "e1", status: "sent"))
        let request = try XCTUnwrap(URLProtocolStub.capturedRequests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        let body = try XCTUnwrap(request.httpBody)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(object, ["productId": "1", "name": "Jane", "email": "jane@example.com", "message": "Hi"])
    }

    // MARK: - HTTP errors

    func testNon2xxWithErrorBodyThrowsServerErrorWithCodeAndMessage() async throws {
        stub(status: 404, json: #"{"error":{"code":"PRODUCT_NOT_FOUND","message":"Product not found.","requestId":"r1"}}"#)
        let client = try makeClient()

        await assertThrowsAsync({ try await client.send(.get("/api/v1/products/999"), as: ProductResponse.self) }) { error in
            XCTAssertEqual(error as? APIError, .server(status: 404, code: "PRODUCT_NOT_FOUND", message: "Product not found.", fieldErrors: []))
        }
    }

    func testValidationErrorIncludesFieldErrors() async throws {
        stub(status: 400, json: """
        {"error":{"code":"VALIDATION_ERROR","message":"Some fields are invalid.","requestId":"r1",
          "details":[{"field":"email","message":"Enter a valid email address."}]}}
        """)
        let client = try makeClient()

        await assertThrowsAsync({ try await client.send(.get("/x"), as: ProductResponse.self) }) { error in
            guard case let .server(status, code, _, fieldErrors)? = error as? APIError else {
                return XCTFail("Unexpected error \(error)")
            }
            XCTAssertEqual(status, 400)
            XCTAssertEqual(code, "VALIDATION_ERROR")
            XCTAssertEqual(fieldErrors, [FieldError(field: "email", message: "Enter a valid email address.")])
        }
    }

    func testNon2xxWithoutJSONBodyStillThrowsServerError() async throws {
        stub(status: 500, json: "<html>Internal Server Error</html>")
        let client = try makeClient()

        await assertThrowsAsync({ try await client.send(.get("/x"), as: ProductResponse.self) }) { error in
            XCTAssertEqual(error as? APIError, .server(status: 500, code: nil, message: nil, fieldErrors: []))
        }
    }

    func testUnexpectedSuccessBodyThrowsDecodingError() async throws {
        stub(status: 200, json: #"{"unexpected":true}"#)
        let client = try makeClient()

        await assertThrowsAsync({ try await client.send(.get("/x"), as: ProductResponse.self) }) { error in
            XCTAssertEqual(error as? APIError, .decoding)
        }
    }

    // MARK: - Transport errors

    func testOfflineMapsToTransportError() async throws {
        stub(error: .notConnectedToInternet)
        let client = try makeClient()

        await assertThrowsAsync({ try await client.send(.get("/x"), as: ProductResponse.self) }) { error in
            XCTAssertEqual(error as? APIError, .transport(.notConnectedToInternet))
        }
    }

    func testBackendNotRunningMapsToTransportError() async throws {
        stub(error: .cannotConnectToHost)
        let client = try makeClient()

        await assertThrowsAsync({ try await client.send(.get("/x"), as: ProductResponse.self) }) { error in
            XCTAssertEqual(error as? APIError, .transport(.cannotConnectToHost))
        }
    }

    func testTimeoutMapsToTimeoutError() async throws {
        stub(error: .timedOut)
        let client = try makeClient()

        await assertThrowsAsync({ try await client.send(.get("/x"), as: ProductResponse.self) }) { error in
            XCTAssertEqual(error as? APIError, .timeout)
        }
    }

    func testCancellationMapsToCancellationError() async throws {
        stub(error: .cancelled)
        let client = try makeClient()

        await assertThrowsAsync({ try await client.send(.get("/x"), as: ProductResponse.self) }) { error in
            XCTAssertTrue(error is CancellationError, "Expected CancellationError, got \(error)")
        }
    }
}
