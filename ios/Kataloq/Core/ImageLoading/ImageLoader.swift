import UIKit

/// Loads product images from the backend-supplied `imageURL` (AD-15).
/// Returns nil on any failure; callers keep showing their placeholder.
@MainActor
protocol ImageLoading: AnyObject {
    func image(for url: URL) async -> UIImage?
}

/// URLSession-based loader with an in-memory cache. Images are decoded off the main
/// thread (`byPreparingForDisplay`) so scrolling stays smooth.
@MainActor
final class URLSessionImageLoader: ImageLoading {
    private let session: URLSession
    private let cache = NSCache<NSURL, UIImage>()

    init(session: URLSession = .shared) {
        self.session = session
        cache.countLimit = 200
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }

        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let image = UIImage(data: data)
            else { return nil }

            let prepared = await image.byPreparingForDisplay() ?? image
            cache.setObject(prepared, forKey: url as NSURL)
            return prepared
        } catch {
            return nil
        }
    }
}
