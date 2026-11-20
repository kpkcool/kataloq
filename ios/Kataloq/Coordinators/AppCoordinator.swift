import UIKit

/// The app's single coordinator (AD-7): builds each screen, injects its dependencies,
/// and turns ViewModel intents into navigation.
///
/// Retention: SceneDelegate → AppCoordinator → UINavigationController → ViewControllers → ViewModels.
/// ViewModel closures capture the coordinator weakly, so there are no cycles.
@MainActor
final class AppCoordinator: Coordinator {
    let navigationController: UINavigationController
    private let dependencies: AppDependencies

    init(navigationController: UINavigationController, dependencies: AppDependencies) {
        self.navigationController = navigationController
        self.dependencies = dependencies
    }

    func start() {
        navigationController.setViewControllers([makeHome()], animated: false)
    }

    // MARK: - Screens

    func makeHome() -> HomeViewController {
        let viewModel = HomeViewModel(repository: dependencies.productRepository)
        viewModel.onProductSelected = { [weak self] productID in self?.showProductDetail(productID: productID) }
        viewModel.onCategorySelected = { [weak self] category in self?.showCategory(category) }
        viewModel.onSearchRequested = { [weak self] in self?.showSearch() }
        return HomeViewController(viewModel: viewModel, imageLoader: dependencies.imageLoader)
    }

    func makeCategory(_ category: ProductCategory) -> CategoryViewController {
        let viewModel = CategoryViewModel(category: category, repository: dependencies.productRepository)
        viewModel.onProductSelected = { [weak self] productID in self?.showProductDetail(productID: productID) }
        return CategoryViewController(viewModel: viewModel, imageLoader: dependencies.imageLoader)
    }

    func makeSearch() -> SearchViewController {
        let viewModel = SearchViewModel(repository: dependencies.productRepository)
        viewModel.onProductSelected = { [weak self] productID in self?.showProductDetail(productID: productID) }
        return SearchViewController(viewModel: viewModel, imageLoader: dependencies.imageLoader)
    }

    func makeProductDetail(productID: String) -> ProductDetailViewController {
        let viewModel = ProductDetailViewModel(productID: productID, repository: dependencies.productRepository)
        viewModel.onEnquireRequested = { [weak self] product in self?.showEnquiry(for: product) }
        return ProductDetailViewController(viewModel: viewModel, imageLoader: dependencies.imageLoader)
    }

    /// The enquiry flow lives in its own navigation controller, presented as a sheet.
    /// On success the form is *replaced* by the thank-you screen, so there's no way "back" to a sent form.
    func makeEnquiryFlow(for product: Product) -> UINavigationController {
        let viewModel = EnquiryViewModel(product: product, repository: dependencies.enquiryRepository)
        let modal = UINavigationController(rootViewController: EnquiryViewController(viewModel: viewModel))

        viewModel.onCancel = { [weak self] in self?.dismissEnquiry() }
        viewModel.onSubmitted = { [weak self, weak modal] confirmation, replyEmail in
            guard let self, let modal else { return }
            let content = ThankYouContent(productTitle: product.title, replyEmail: replyEmail, enquiryID: confirmation.enquiryId)
            modal.setViewControllers([self.makeThankYou(content)], animated: true)
        }
        return modal
    }

    func makeThankYou(_ content: ThankYouContent) -> ThankYouViewController {
        ThankYouViewController(content: content, onDone: { [weak self] in self?.dismissEnquiry() })
    }

    // MARK: - Navigation

    func showCategory(_ category: ProductCategory) {
        navigationController.pushViewController(makeCategory(category), animated: true)
    }

    func showSearch() {
        navigationController.pushViewController(makeSearch(), animated: true)
    }

    func showProductDetail(productID: String) {
        navigationController.pushViewController(makeProductDetail(productID: productID), animated: true)
    }

    func showEnquiry(for product: Product) {
        navigationController.present(makeEnquiryFlow(for: product), animated: true)
    }

    func dismissEnquiry() {
        navigationController.dismiss(animated: true)
    }
}
