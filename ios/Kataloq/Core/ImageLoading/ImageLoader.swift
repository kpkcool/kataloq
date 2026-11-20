import UIKit

/// Loads product images from the backend-supplied `imageURL` (AD-15).
/// Returns nil on any failure; callers show their fallback.
@MainActor
protocol ImageLoading: AnyObject {
    func image(for url: URL) async -> UIImage?
}

/// URLSession-based loader:
/// - in-memory cache (`NSCache`), so scrolling back never re-downloads;
/// - one shared download per URL while it's in flight, so the same image requested by
///   several cards at once (e.g. a product in both Home "Featured" and "All Products")
///   is fetched only once;
/// - images decoded off the main thread (`byPreparingForDisplay`) to keep scrolling smooth.
///
/// A caller that's cancelled (a reused cell) stops waiting, but the shared download finishes
/// and fills the cache, which helps when the user scrolls back.
@MainActor
final class URLSessionImageLoader: ImageLoading {
    private let session: URLSession
    private let cache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    init(session: URLSession = .shared) {
        self.session = session
        cache.countLimit = 200
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        if let existing = inFlight[url] { return await existing.value }

        let session = self.session
        let download = Task<UIImage?, Never> {
            do {
                let (data, response) = try await session.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode),
                      let image = UIImage(data: data)
                else { return nil }
                return await image.byPreparingForDisplay() ?? image
            } catch {
                return nil
            }
        }
        inFlight[url] = download

        let image = await download.value
        inFlight[url] = nil
        if let image {
            cache.setObject(image, forKey: url as NSURL)
        }
        return image
    }
}
