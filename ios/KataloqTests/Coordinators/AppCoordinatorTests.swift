import UIKit
import XCTest
@testable import Kataloq

@MainActor
final class AppCoordinatorTests: XCTestCase {
    private func makeSUT() -> (AppCoordinator, UINavigationController) {
        let navigationController = UINavigationController()
        let dependencies = AppDependencies(
            productRepository: MockProductRepository(),
            enquiryRepository: MockEnquiryRepository(),
            imageLoader: MockImageLoader()
        )
        let sut = AppCoordinator(navigationController: navigationController, dependencies: dependencies)
        trackForMemoryLeaks(sut)
        return (sut, navigationController)
    }

    func testStartShowsHomeAsTheRootScreen() {
        let (sut, navigationController) = makeSUT()

        sut.start()

        XCTAssertEqual(navigationController.viewControllers.count, 1)
        XCTAssertTrue(navigationController.viewControllers.first is HomeViewController)
        XCTAssertEqual(navigationController.viewControllers.first?.title, "Kataloq")
    }

    func testShowCategoryPushesTheCategoryScreen() {
        let (sut, navigationController) = makeSUT()
        sut.start()

        sut.showCategory(Fixtures.jewelery)

        XCTAssertEqual(navigationController.viewControllers.count, 2)
        XCTAssertTrue(navigationController.viewControllers.last is CategoryViewController)
        XCTAssertEqual(navigationController.viewControllers.last?.title, "Jewelery")
    }

    func testShowSearchPushesTheSearchScreen() {
        let (sut, navigationController) = makeSUT()
        sut.start()

        sut.showSearch()

        XCTAssertTrue(navigationController.viewControllers.last is SearchViewController)
        XCTAssertEqual(navigationController.viewControllers.last?.title, "Search")
    }

    func testShowProductDetailPushesTheDetailScreen() {
        let (sut, navigationController) = makeSUT()
        sut.start()

        sut.showProductDetail(productID: "1")

        XCTAssertTrue(navigationController.viewControllers.last is ProductDetailViewController)
    }

    func testEnquiryFlowStartsWithTheFormInItsOwnNavigationController() {
        let (sut, _) = makeSUT()

        let flow = sut.makeEnquiryFlow(for: Fixtures.product(id: "1", title: "Backpack"))

        XCTAssertEqual(flow.viewControllers.count, 1)
        XCTAssertTrue(flow.viewControllers.first is EnquiryViewController)
        XCTAssertEqual(flow.viewControllers.first?.title, "Enquiry")
        trackForMemoryLeaks(flow)
    }

    func testThankYouScreen() {
        let (sut, _) = makeSUT()

        let thankYou = sut.makeThankYou(ThankYouContent(productTitle: "Backpack", replyEmail: "jane@example.com", enquiryID: "e1"))

        XCTAssertEqual(thankYou.title, "Enquiry sent")
        trackForMemoryLeaks(thankYou)
    }

    func testScreensDoNotRetainTheCoordinator() {
        let (sut, _) = makeSUT()
        let home = sut.makeHome()
        let category = sut.makeCategory(Fixtures.electronics)
        let search = sut.makeSearch()
        let detail = sut.makeProductDetail(productID: "1")
        trackForMemoryLeaks(detail)
        trackForMemoryLeaks(home)
        trackForMemoryLeaks(category)
        trackForMemoryLeaks(search)
    }
}
