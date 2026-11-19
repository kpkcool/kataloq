import Foundation

/// Intercepts URLSession requests so the real networking code can be tested without a server.
final class URLProtocolStub: URLProtocol {
    struct Stub {
        var data = Data()
        var statusCode: Int?
        var error: Error?
    }

    nonisolated(unsafe) static var stub: Stub?
    nonisolated(unsafe) static var capturedRequests: [URLRequest] = []

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    static func reset() {
        stub = nil
        capturedRequests = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var captured = request
        // URLSession moves httpBody into a stream before it reaches a URLProtocol.
        if captured.httpBody == nil, let stream = request.httpBodyStream {
            captured.httpBody = Data(reading: stream)
        }
        Self.capturedRequests.append(captured)

        guard let stub = Self.stub else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        if let statusCode = stub.statusCode,
           let url = request.url,
           let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: "HTTP/1.1", headerFields: nil) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: stub.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension Data {
    init(reading stream: InputStream) {
        self.init()
        stream.open()
        defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            append(buffer, count: count)
        }
    }
}
