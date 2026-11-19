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

    // MARK: - Navigation
    // Destinations are added screen by screen in Phase 4 (Category → Search → Product detail → Enquiry).

    func showCategory(_ category: ProductCategory) {}

    func showSearch() {}

    func showProductDetail(productID: String) {}
}
