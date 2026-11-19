import UIKit

/// Category: "Top Rated" as a horizontally scrolling row, then "All Products" as a 2-column grid.
final class CategoryViewController: UIViewController {
    private enum Section: Hashable {
        case topRated
        case allProducts

        var title: String {
            switch self {
            case .topRated: return "Top Rated"
            case .allProducts: return "All Products"
            }
        }
    }

    private let viewModel: CategoryViewModel
    private let imageLoader: any ImageLoading

    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
    private lazy var dataSource = makeDataSource()
    private let stateView = StateView()
    private let refreshControl = UIRefreshControl()
    private var loadTask: Task<Void, Never>?

    init(viewModel: CategoryViewModel, imageLoader: any ImageLoading) {
        self.viewModel = viewModel
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
        configureCollectionView()
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
        reload()
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

    /// The task holds the ViewModel, not this controller, so leaving the screen deallocates the
    /// controller and `deinit` cancels the request.
    private func reload() {
        loadTask?.cancel()
        let viewModel = self.viewModel
        loadTask = Task { await viewModel.load() }
    }

    // MARK: - Rendering

    private func render(_ state: LoadState<CategoryContent>) {
        switch state {
        case .idle:
            break
        case .loading:
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

    private func applySnapshot(_ content: CategoryContent?) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, ProductCardViewData>()
        if let content {
            if !content.topRated.isEmpty {
                snapshot.appendSections([.topRated])
                snapshot.appendItems(content.topRated, toSection: .topRated)
            }
            if !content.allProducts.isEmpty {
                snapshot.appendSections([.allProducts])
                snapshot.appendItems(content.allProducts, toSection: .allProducts)
            }
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: - Collection view

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, ProductCardViewData> {
        let imageLoader = self.imageLoader

        let productRegistration = UICollectionView.CellRegistration<ProductCardCell, ProductCardViewData> { cell, _, item in
            cell.configure(with: item, imageLoader: imageLoader)
        }
        let headerRegistration = UICollectionView.SupplementaryRegistration<SectionHeaderView>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, indexPath in
            guard let section = self?.dataSource.sectionIdentifier(for: indexPath.section) else { return }
            header.configure(title: section.title)
        }

        let dataSource = UICollectionViewDiffableDataSource<Section, ProductCardViewData>(
            collectionView: collectionView
        ) { collectionView, indexPath, item in
            collectionView.dequeueConfiguredReusableCell(using: productRegistration, for: indexPath, item: item)
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
            case .topRated: return LayoutSections.productCarousel()
            case .allProducts: return LayoutSections.productGrid()
            }
        }
    }
}

// MARK: - UICollectionViewDelegate

extension CategoryViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        viewModel.selectProduct(id: item.id)
    }
}
