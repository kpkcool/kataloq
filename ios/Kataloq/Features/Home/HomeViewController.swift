import UIKit

/// Home: category chips, a horizontally scrolling "Featured" row (the 5 curated products), then an
/// "All Products" grid.
/// Renders `HomeViewModel.state` and forwards taps; no networking or navigation here.
final class HomeViewController: UIViewController {
    private enum Section: Hashable {
        case categories
        case featured
        case allProducts

        var title: String {
            switch self {
            case .categories: return "Shop by category"
            case .featured: return "Featured"
            case .allProducts: return "All Products"
            }
        }
    }

    /// Featured products also appear in "All Products". Separate cases keep the two items distinct,
    /// because a diffable data source can't hold the same item twice.
    private enum Item: Hashable {
        case category(ProductCategory)
        case featured(ProductCardViewData)
        case product(ProductCardViewData)

        var productID: String? {
            switch self {
            case .category: return nil
            case .featured(let product), .product(let product): return product.id
            }
        }
    }

    private let viewModel: HomeViewModel
    private let imageLoader: any ImageLoading
    private let searchResultsController: SearchViewController

    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
    private lazy var dataSource = makeDataSource()
    private let stateView = StateView()
    private let refreshControl = UIRefreshControl()
    private var loadTask: Task<Void, Never>?

    init(viewModel: HomeViewModel, searchResultsController: SearchViewController, imageLoader: any ImageLoading) {
        self.viewModel = viewModel
        self.searchResultsController = searchResultsController
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
        title = viewModel.title
    }

    required init?(coder: NSCoder) {
        return nil
    }

    deinit {
        loadTask?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        configureNavigationItem()
        configureCollectionView()
        bindViewModel()
        reload()
    }

    // MARK: - Setup

    /// Search bar at the top of Home, under the large title and above the categories.
    /// Results appear over Home in the same screen (`SearchViewController` is the search
    /// controller's results view) and update as the user types.
    private func configureNavigationItem() {
        let searchController = UISearchController(searchResultsController: searchResultsController)
        searchController.searchResultsUpdater = searchResultsController
        searchController.obscuresBackgroundDuringPresentation = false
        let searchBar = searchController.searchBar
        searchBar.delegate = searchResultsController
        searchBar.placeholder = "Search products"
        searchBar.returnKeyType = .search
        searchBar.autocorrectionType = .no
        searchBar.searchTextField.accessibilityLabel = "Search products"

        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        navigationItem.preferredSearchBarPlacement = .stacked
        if #available(iOS 26.0, *) {
            // iOS 26 otherwise moves the search field into a bottom toolbar on iPhone.
            navigationItem.searchBarPlacementAllowsToolbarIntegration = false
        }
        // Pushing a product from the results keeps the search (and its results) when coming back.
        definesPresentationContext = true
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
                snapshot.appendItems(content.featured.map(Item.featured), toSection: .featured)
            }
            if !content.allProducts.isEmpty {
                snapshot.appendSections([.allProducts])
                snapshot.appendItems(content.allProducts.map(Item.product), toSection: .allProducts)
            }
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - Collection view

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        let imageLoader = self.imageLoader

        // One cell class, two styles: the section decides how a product is presented.
        let featuredRegistration = UICollectionView.CellRegistration<ProductCardCell, ProductCardViewData> { cell, _, item in
            cell.configure(with: item, style: .featured, imageLoader: imageLoader)
        }
        let standardRegistration = UICollectionView.CellRegistration<ProductCardCell, ProductCardViewData> { cell, _, item in
            cell.configure(with: item, style: .standard, imageLoader: imageLoader)
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
            case .featured(let product):
                return collectionView.dequeueConfiguredReusableCell(using: featuredRegistration, for: indexPath, item: product)
            case .product(let product):
                return collectionView.dequeueConfiguredReusableCell(using: standardRegistration, for: indexPath, item: product)
            }
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
        return dataSource
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let section = self?.dataSource.sectionIdentifier(for: sectionIndex) else { return nil }
            switch section {
            case .categories: return LayoutSections.chipRow()
            case .featured: return LayoutSections.productCarousel(environment: environment)
            case .allProducts: return LayoutSections.productGrid(environment: environment)
            }
        }
    }
}

// MARK: - UICollectionViewDelegate

extension HomeViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        if case .category(let category) = item {
            viewModel.selectCategory(category)
        } else if let productID = item.productID {
            viewModel.selectProduct(id: productID)
        }
    }
}
