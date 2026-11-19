import UIKit

/// Home: a horizontal row of category chips and a 2-column grid of featured products.
/// Renders `HomeViewModel.state` and forwards taps; no networking or navigation here.
final class HomeViewController: UIViewController {
    private enum Section: Hashable {
        case categories
        case featured

        var title: String {
            switch self {
            case .categories: return "Shop by category"
            case .featured: return "Featured"
            }
        }
    }

    private enum Item: Hashable {
        case category(ProductCategory)
        case product(ProductCardViewData)
    }

    private let viewModel: HomeViewModel
    private let imageLoader: any ImageLoading

    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
    private lazy var dataSource = makeDataSource()
    private let stateView = StateView()
    private let refreshControl = UIRefreshControl()
    private var loadTask: Task<Void, Never>?

    init(viewModel: HomeViewModel, imageLoader: any ImageLoading) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    deinit {
        loadTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = viewModel.title
        view.backgroundColor = Theme.Color.background
        configureNavigationItem()
        configureCollectionView()
        bindViewModel()
        reload()
    }

    // MARK: - Setup

    private func configureNavigationItem() {
        let searchButton = UIBarButtonItem(
            systemItem: .search,
            primaryAction: UIAction { [weak self] _ in self?.viewModel.requestSearch() }
        )
        searchButton.accessibilityLabel = "Search products"
        navigationItem.rightBarButtonItem = searchButton
    }

    private func configureCollectionView() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = Theme.Color.background
        collectionView.delegate = self
        collectionView.refreshControl = refreshControl
        refreshControl.addAction(UIAction { [weak self] _ in self?.reload() }, for: .valueChanged)
        stateView.onRetry = { [weak self] in self?.reload() }

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
    }

    /// The task holds the ViewModel, not this controller, so the controller can deallocate
    /// (and cancel the load in `deinit`) while a request is in flight.
    private func reload() {
        loadTask?.cancel()
        let viewModel = self.viewModel
        loadTask = Task { await viewModel.load() }
    }

    // MARK: - Rendering

    private func render(_ state: LoadState<HomeContent>) {
        switch state {
        case .idle:
            break
        case .loading:
            // Pull-to-refresh keeps the current content visible; a first load shows the spinner.
            if dataSource.snapshot().numberOfItems == 0 {
                showState(.loading)
            }
        case .loaded(let content):
            refreshControl.endRefreshing()
            collectionView.backgroundView = nil
            applySnapshot(content)
        case .empty(let message):
            refreshControl.endRefreshing()
            applySnapshot(nil)
            showState(.message(message))
        case .failed(let message):
            refreshControl.endRefreshing()
            applySnapshot(nil)
            showState(.error(message))
        }
    }

    private func showState(_ content: StateView.Content) {
        stateView.configure(content)
        collectionView.backgroundView = stateView
    }

    private func applySnapshot(_ content: HomeContent?) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        if let content {
            if !content.categories.isEmpty {
                snapshot.appendSections([.categories])
                snapshot.appendItems(content.categories.map(Item.category), toSection: .categories)
            }
            if !content.featured.isEmpty {
                snapshot.appendSections([.featured])
                snapshot.appendItems(content.featured.map(Item.product), toSection: .featured)
            }
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - Collection view

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        let imageLoader = self.imageLoader

        let productRegistration = UICollectionView.CellRegistration<ProductCardCell, ProductCardViewData> { cell, _, item in
            cell.configure(with: item, imageLoader: imageLoader)
        }
        let categoryRegistration = UICollectionView.CellRegistration<CategoryChipCell, ProductCategory> { cell, _, category in
            cell.configure(with: category)
        }
        let headerRegistration = UICollectionView.SupplementaryRegistration<SectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, indexPath in
            guard let section = self?.dataSource.sectionIdentifier(for: indexPath.section) else { return }
            header.configure(title: section.title)
        }

        let dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { collectionView, indexPath, item in
            switch item {
            case .category(let category):
                return collectionView.dequeueConfiguredReusableCell(using: categoryRegistration, for: indexPath, item: category)
            case .product(let product):
                return collectionView.dequeueConfiguredReusableCell(using: productRegistration, for: indexPath, item: product)
            }
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
        return dataSource
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, _ in
            guard let section = self?.dataSource.sectionIdentifier(for: sectionIndex) else { return nil }
            switch section {
            case .categories: return HomeViewController.categoriesSection()
            case .featured: return LayoutSections.productGrid()
            }
        }
    }

    private static func categoriesSection() -> NSCollectionLayoutSection {
        let size = NSCollectionLayoutSize(widthDimension: .estimated(120), heightDimension: .estimated(36))
        let item = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = Theme.Spacing.small
        section.contentInsets = NSDirectionalEdgeInsets(
            top: Theme.Spacing.small, leading: Theme.Spacing.large,
            bottom: Theme.Spacing.xLarge, trailing: Theme.Spacing.large
        )
        section.boundarySupplementaryItems = [LayoutSections.header()]
        return section
    }
}

// MARK: - UICollectionViewDelegate

extension HomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .category(let category):
            viewModel.selectCategory(category)
        case .product(let product):
            viewModel.selectProduct(id: product.id)
        }
    }
}
