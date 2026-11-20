import XCTest

extension XCTestCase {
    /// Fails the test if `instance` is still alive after the test: a sign of a retain cycle.
    func trackForMemoryLeaks(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            XCTAssertNil(instance, "Instance should have been deallocated. Potential retain cycle.", file: file, line: line)
        }
    }

    /// Async equivalent of XCTAssertThrowsError.
    func assertThrowsAsync<T>(
        _ expression: () async throws -> T,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ verify: (Error) -> Void = { _ in }
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected an error to be thrown", file: file, line: line)
        } catch {
            verify(error)
        }
    }
}
