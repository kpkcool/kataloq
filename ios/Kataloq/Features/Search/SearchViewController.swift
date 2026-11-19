import UIKit

/// Search: a search field in the navigation bar; results in a 2-column grid.
/// The search runs when the user taps the keyboard's Search button (the brief's "search button").
final class SearchViewController: UIViewController {
    private enum Section: Hashable {
        case results
    }

    private let viewModel: SearchViewModel
    private let imageLoader: any ImageLoading

    private let searchController = UISearchController(searchResultsController: nil)
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
    private lazy var dataSource = makeDataSource()
    private let stateView = StateView()
    private var resultsTitle = ""
    private var hasAppeared = false

    init(viewModel: SearchViewModel, imageLoader: any ImageLoading) {
        self.viewModel = viewModel
        self.imageLoader = imageLoader
        super.init(nibName: nil, bundle: nil)
        title = viewModel.title
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        navigationItem.largeTitleDisplayMode = .never
        configureSearchController()
        configureCollectionView()
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
        render(viewModel.state)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Focus the field the first time, so the keyboard is ready when the screen opens.
        guard !hasAppeared else { return }
        hasAppeared = true
        searchController.searchBar.becomeFirstResponder()
    }

    // MARK: - Setup

    private func configureSearchController() {
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.placeholder = viewModel.placeholder
        searchController.searchBar.returnKeyType = .search
        searchController.searchBar.enablesReturnKeyAutomatically = true
        searchController.searchBar.autocorrectionType = .no
        searchController.searchBar.delegate = self
        searchController.searchBar.accessibilityLabel = "Search products"
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    private func configureCollectionView() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = Theme.Color.background
        collectionView.keyboardDismissMode = .onDrag
        collectionView.delegate = self
        stateView.onRetry = { [weak self] in self?.viewModel.retry() }

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Rendering

    private func render(_ state: SearchState) {
        switch state {
        case .idle:
            applySnapshot(nil)
            showState(.message("Search by product name, description or category."))
        case .invalidQuery(let message):
            applySnapshot(nil)
            showState(.message(message))
        case .loading:
            applySnapshot(nil)
            showState(.loading)
        case .results(let results):
            collectionView.backgroundView = nil
            applySnapshot(results)
            UIAccessibility.post(notification: .announcement, argument: results.title)
        case .noResults(let query):
            applySnapshot(nil)
            showState(.message("No products match \u{201C}\(query)\u{201D}. Try a different word."))
        case .failed(_, let message):
            applySnapshot(nil)
            showState(.error(message))
        }
    }

    private func showState(_ content: StateView.Content) {
        stateView.configure(content)
        collectionView.backgroundView = stateView
    }

    private func applySnapshot(_ results: SearchResults?) {
        resultsTitle = results?.title ?? ""
        var snapshot = NSDiffableDataSourceSnapshot<Section, ProductCardViewData>()
        if let results {
            snapshot.appendSections([.results])
            snapshot.appendItems(results.products, toSection: .results)
            // The header text depends on the query, so refresh it even if the products are the same.
            snapshot.reloadSections([.results])
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
        ) { [weak self] header, _, _ in
            header.configure(title: self?.resultsTitle ?? "")
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
        UICollectionViewCompositionalLayout { _, _ in
            LayoutSections.productGrid()
        }
    }
}

// MARK: - UISearchBarDelegate

extension SearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        viewModel.submitSearch(searchBar.text ?? "")
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        viewModel.clear()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Clearing the field (the ⓧ button) returns to the prompt.
        if searchText.isEmpty {
            viewModel.clear()
        }
    }
}

// MARK: - UICollectionViewDelegate

extension SearchViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        viewModel.selectProduct(id: item.id)
    }
}
