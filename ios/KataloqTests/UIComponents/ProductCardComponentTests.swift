import UIKit
import XCTest
@testable import Kataloq

/// The product card components only display what they are given; these tests check they show
/// the configuration they receive and fall back correctly when an image is missing.
@MainActor
final class ProductCardComponentTests: XCTestCase {
    func testCardShowsTheConfiguredProduct() {
        let card = ProductCardView()
        let item = ProductCardViewData(
            product: Fixtures.product(title: "Backpack", amount: 109.95, average: 3.9, count: 120),
            locale: Fixtures.usLocale
        )

        card.configure(with: item, style: .featured, imageLoader: StubImageLoader(image: nil))

        XCTAssertEqual(card.titleView.text, "Backpack")
        XCTAssertEqual(card.priceView.text, "$109.95")
        XCTAssertEqual(card.ratingView.displayedText, "3.9 (120)")
        XCTAssertFalse(card.ratingView.isStarHidden)
        XCTAssertEqual(card.style, .featured)
        XCTAssertEqual(card.imageView.padding, Theme.ProductCard.featuredImagePadding)
    }

    func testStandardStyleUsesStandardImagePadding() {
        let card = ProductCardView()
        let item = ProductCardViewData(product: Fixtures.product(), locale: Fixtures.usLocale)

        card.configure(with: item, style: .standard, imageLoader: StubImageLoader(image: nil))

        XCTAssertEqual(card.imageView.padding, Theme.ProductCard.standardImagePadding)
    }

    func testUnratedProductHidesTheStar() {
        let rating = ProductRatingView()

        rating.configure(score: "0.0", count: "(0)", isRated: false)

        XCTAssertTrue(rating.isStarHidden)
        XCTAssertEqual(rating.displayedText, "No ratings yet")
    }

    func testCellExposesOneAccessibilityElement() {
        let cell = ProductCardCell(frame: CGRect(x: 0, y: 0, width: 170, height: 300))
        let item = ProductCardViewData(product: Fixtures.product(title: "Backpack"), locale: Fixtures.usLocale)

        cell.configure(with: item, style: .standard, imageLoader: StubImageLoader(image: nil))

        XCTAssertTrue(cell.isAccessibilityElement)
        XCTAssertEqual(cell.accessibilityLabel, item.accessibilityLabel)
    }

    func testCardUsesTheSharedShadowAndSeparatesShadowFromClipping() {
        let card = ProductCardView(frame: CGRect(x: 0, y: 0, width: 170, height: 300))
        card.layoutIfNeeded()

        XCTAssertEqual(card.layer.shadowOpacity, Theme.ProductCard.Shadow.opacity)
        XCTAssertEqual(card.layer.shadowRadius, Theme.ProductCard.Shadow.radius)
        XCTAssertEqual(card.layer.shadowOffset, Theme.ProductCard.Shadow.offset)
        XCTAssertFalse(card.layer.masksToBounds, "The shadow layer must not clip, or the shadow disappears")
        XCTAssertNotNil(card.layer.shadowPath, "An explicit shadow path keeps scrolling smooth")
        XCTAssertTrue(card.surfaceView.clipsToBounds)
        XCTAssertEqual(card.surfaceView.layer.cornerRadius, Theme.ProductCard.cornerRadius)
        XCTAssertEqual(card.surfaceView.layer.borderWidth, Theme.ProductCard.borderWidth)
    }

    /// Carousels are as tall as their tallest card, and off-screen cards only have the estimate.
    /// If the estimate were taller than a real card, the row would shrink while scrolling.
    func testHeightEstimateStaysJustBelowTheRealCardHeight() {
        for width: CGFloat in [144, 152, 172, 180] {
            let card = ProductCardView()
            card.configure(
                with: ProductCardViewData(product: Fixtures.product(title: "A long product name that needs two lines"), locale: Fixtures.usLocale),
                style: .featured,
                imageLoader: StubImageLoader(image: nil)
            )
            let real = card.systemLayoutSizeFitting(
                CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel
            ).height

            let estimate = LayoutSections.estimatedCardHeight(forWidth: width)

            XCTAssertLessThanOrEqual(estimate, real, "width \(width)")
            XCTAssertLessThan(real - estimate, 10, "width \(width): estimate drifted from the real layout")
        }
    }

    // MARK: - ProductImageView

    func testMissingURLShowsTheFallbackWithoutLoading() {
        let imageView = ProductImageView()
        let loader = StubImageLoader(image: nil)

        imageView.load(nil, using: loader)

        XCTAssertEqual(imageView.loadingState, .unavailable)
        XCTAssertTrue(loader.requestedURLs.isEmpty)
    }

    func testFailedDownloadShowsTheFallback() async {
        let imageView = ProductImageView()
        let url = URL(string: "https://example.com/missing.png")!

        imageView.load(url, using: StubImageLoader(image: nil))
        XCTAssertEqual(imageView.loadingState, .loading)
        await imageView.loadTask?.value

        XCTAssertEqual(imageView.loadingState, .unavailable)
    }

    func testSuccessfulDownloadShowsTheImage() async {
        let imageView = ProductImageView()
        let url = URL(string: "https://example.com/product.png")!

        imageView.load(url, using: StubImageLoader(image: TestImage.make()))
        await imageView.loadTask?.value

        XCTAssertEqual(imageView.loadingState, .loaded)
    }

    func testResetCancelsTheLoadAndShowsThePlaceholder() async {
        let imageView = ProductImageView()
        imageView.load(URL(string: "https://example.com/product.png")!, using: StubImageLoader(image: TestImage.make()))
        let task = imageView.loadTask

        imageView.reset()
        await task?.value

        XCTAssertEqual(imageView.loadingState, .loading)
    }
}

// MARK: - URLSessionImageLoader

@MainActor
final class URLSessionImageLoaderTests: XCTestCase {
    private let url = URL(string: "https://example.com/product.png")!

    override func setUp() {
        super.setUp()
        URLProtocolStub.reset()
    }

    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    func testDownloadsAndDecodesAnImage() async {
        URLProtocolStub.stub = .init(data: TestImage.pngData(), statusCode: 200)
        let loader = URLSessionImageLoader(session: URLProtocolStub.makeSession())

        let image = await loader.image(for: url)

        XCTAssertNotNil(image)
    }

    func testSecondRequestIsServedFromTheCache() async {
        URLProtocolStub.stub = .init(data: TestImage.pngData(), statusCode: 200)
        let loader = URLSessionImageLoader(session: URLProtocolStub.makeSession())

        _ = await loader.image(for: url)
        let second = await loader.image(for: url)

        XCTAssertNotNil(second)
        XCTAssertEqual(URLProtocolStub.capturedRequests.count, 1)
    }

    func testConcurrentRequestsForTheSameURLShareOneDownload() async {
        URLProtocolStub.stub = .init(data: TestImage.pngData(), statusCode: 200)
        let loader = URLSessionImageLoader(session: URLProtocolStub.makeSession())

        async let first = loader.image(for: url)
        async let second = loader.image(for: url)
        let images = await [first, second]

        XCTAssertEqual(images.compactMap { $0 }.count, 2)
        XCTAssertEqual(URLProtocolStub.capturedRequests.count, 1)
    }

    func testHTTPErrorReturnsNil() async {
        URLProtocolStub.stub = .init(data: TestImage.pngData(), statusCode: 404)
        let loader = URLSessionImageLoader(session: URLProtocolStub.makeSession())

        let image = await loader.image(for: url)

        XCTAssertNil(image)
    }

    func testDataThatIsNotAnImageReturnsNil() async {
        URLProtocolStub.stub = .init(data: Data("not an image".utf8), statusCode: 200)
        let loader = URLSessionImageLoader(session: URLProtocolStub.makeSession())

        let image = await loader.image(for: url)

        XCTAssertNil(image)
    }

    func testFailureIsNotCached() async {
        URLProtocolStub.stub = .init(data: Data(), statusCode: 500)
        let loader = URLSessionImageLoader(session: URLProtocolStub.makeSession())
        _ = await loader.image(for: url)

        URLProtocolStub.stub = .init(data: TestImage.pngData(), statusCode: 200)
        let retry = await loader.image(for: url)

        XCTAssertNotNil(retry)
        XCTAssertEqual(URLProtocolStub.capturedRequests.count, 2)
    }
}

// MARK: - Helpers

private final class StubImageLoader: ImageLoading {
    private let image: UIImage?
    private(set) var requestedURLs: [URL] = []

    init(image: UIImage?) {
        self.image = image
    }

    func image(for url: URL) async -> UIImage? {
        requestedURLs.append(url)
        return image
    }
}

private enum TestImage {
    static func make() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }

    static func pngData() -> Data {
        make().pngData() ?? Data()
    }
}
