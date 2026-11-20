import XCTest
@testable import Kataloq

final class AppConfigurationTests: XCTestCase {
    func testUsesInfoPlistValue() {
        let config = AppConfiguration.load(infoDictionary: ["KataloqAPIBaseURL": "http://localhost:4000"], environment: [:])
        XCTAssertEqual(config.apiBaseURL.absoluteString, "http://localhost:4000")
    }

    func testEnvironmentOverridesInfoPlist() {
        let config = AppConfiguration.load(
            infoDictionary: ["KataloqAPIBaseURL": "http://localhost:4000"],
            environment: ["KATALOQ_API_BASE_URL": "http://192.168.1.20:3000"]
        )
        XCTAssertEqual(config.apiBaseURL.absoluteString, "http://192.168.1.20:3000")
    }

    func testFallsBackToLocalhostWhenNothingIsConfigured() {
        let config = AppConfiguration.load(infoDictionary: nil, environment: [:])
        XCTAssertEqual(config.apiBaseURL.absoluteString, "http://localhost:3000")
    }

    func testIgnoresUnexpandedBuildSettingAndInvalidValues() {
        for value in ["$(API_BASE_URL)", "", "   ", "not a url", "ftp://example.com"] {
            let config = AppConfiguration.load(infoDictionary: ["KataloqAPIBaseURL": value], environment: [:])
            XCTAssertEqual(config.apiBaseURL, AppConfiguration.defaultBaseURL, "Value: \(value)")
        }
    }
}

final class ProductFormattingTests: XCTestCase {
    private let locale = Fixtures.usLocale

    func testFormatsPriceInTheProductsCurrency() {
        XCTAssertEqual(ProductFormatting.price(Price(amount: 109.95, currency: "USD"), locale: locale), "$109.95")
        XCTAssertEqual(ProductFormatting.price(Price(amount: 9, currency: "USD"), locale: locale), "$9.00")
    }

    func testFormatsRatingWithOneDecimalAndCount() {
        XCTAssertEqual(ProductFormatting.rating(Rating(average: 4.6, count: 400), locale: locale), "★ 4.6 (400)")
        XCTAssertEqual(ProductFormatting.rating(Rating(average: 4, count: 1), locale: locale), "★ 4.0 (1)")
    }

    func testRatingValueOmitsTheStarForIconLayouts() {
        XCTAssertEqual(ProductFormatting.ratingValue(Rating(average: 4.6, count: 400), locale: locale), "4.6 (400)")
        XCTAssertEqual(ProductFormatting.ratingValue(Rating(average: 0, count: 0), locale: locale), "No ratings yet")
    }

    func testUnratedProductSaysSo() {
        XCTAssertEqual(ProductFormatting.rating(Rating(average: 0, count: 0), locale: locale), "No ratings yet")
    }

    func testRatingAccessibilityReadsNaturally() {
        XCTAssertEqual(
            ProductFormatting.ratingAccessibility(Rating(average: 4.6, count: 400), locale: locale),
            "Rated 4.6 out of 5 from 400 reviews"
        )
        XCTAssertEqual(
            ProductFormatting.ratingAccessibility(Rating(average: 5, count: 1), locale: locale),
            "Rated 5.0 out of 5 from 1 review"
        )
    }

    func testCardViewDataCombinesEverythingForVoiceOver() {
        let product = Fixtures.product(id: "1", title: "Backpack", amount: 109.95, average: 3.9, count: 120)

        let card = ProductCardViewData(product: product, locale: locale)

        XCTAssertEqual(card.accessibilityLabel, "Backpack, $109.95, Rated 3.9 out of 5 from 120 reviews")
    }
}
