import UIKit

/// Product detail: image, category, title, price, rating, description, and a sticky Enquire button.
final class ProductDetailViewController: UIViewController {
    private let viewModel: ProductDetailViewModel
    private let imageLoader: any ImageLoading

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    /// Same image component as the product cards, larger padding and a slightly shorter tile.
    private let productImageView = ProductImageView(aspectRatio: 0.85)
    private let categoryLabel = UILabel()
    private let titleLabel = UILabel()
    private let priceLabel = UILabel()
    private let ratingView = ProductRatingView()
    private let descriptionHeaderLabel = UILabel()
    private let descriptionLabel = UILabel()
    private let bottomBar = UIView()
    private let enquireButton = UIButton(configuration: .filled())
    private let stateView = StateView()

    private static let hairline: CGFloat = 0.5

    private var loadTask: Task<Void, Never>?

    init(viewModel: ProductDetailViewModel, imageLoader: any ImageLoading) {
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
        view.backgroundColor = Theme.Color.background
        navigationItem.largeTitleDisplayMode = .never
        setUpViews()
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
        reload()
    }

    private func reload() {
        loadTask?.cancel()
        let viewModel = self.viewModel
        loadTask = Task { await viewModel.load() }
    }

    // MARK: - Rendering

    private func render(_ state: LoadState<ProductDetailContent>) {
        switch state {
        case .idle:
            break
        case .loading:
            showState(.loading)
        case .loaded(let content):
            hideState()
            show(content)
        case .empty(let message):
            showState(.message(message))
        case .failed(let message):
            showState(.error(message))
        }
    }

    private func show(_ content: ProductDetailContent) {
        categoryLabel.text = content.categoryName.uppercased()
        categoryLabel.accessibilityLabel = "Category: \(content.categoryName)"
        titleLabel.text = content.title
        priceLabel.text = content.priceText
        ratingView.configure(score: content.ratingScoreText, count: content.ratingCountText, isRated: content.isRated)
        ratingView.accessibilityLabel = content.ratingAccessibilityText
        descriptionLabel.text = content.description
        productImageView.load(content.imageURL, using: imageLoader)
    }

    /// Loading and error cover the content; the Enquire button only appears with a loaded product.
    private func showState(_ content: StateView.Content) {
        stateView.configure(content)
        stateView.isHidden = false
        scrollView.isHidden = true
        bottomBar.isHidden = true
    }

    private func hideState() {
        stateView.isHidden = true
        scrollView.isHidden = false
        bottomBar.isHidden = false
    }

    // MARK: - Layout

    private func setUpViews() {
        configureLabels()
        configureImage()
        configureBottomBar()

        contentStack.axis = .vertical
        contentStack.spacing = Theme.Spacing.small
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        [productImageView, categoryLabel, titleLabel, priceLabel, ratingView, descriptionHeaderLabel, descriptionLabel]
            .forEach(contentStack.addArrangedSubview)
        contentStack.setCustomSpacing(Theme.Spacing.large + 4, after: productImageView)
        contentStack.setCustomSpacing(Theme.Spacing.xLarge, after: ratingView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.addSubview(contentStack)

        stateView.translatesAutoresizingMaskIntoConstraints = false
        stateView.onRetry = { [weak self] in self?.reload() }

        [scrollView, bottomBar, stateView].forEach { view.addSubview($0) }

        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            contentStack.topAnchor.constraint(equalTo: content.topAnchor, constant: Theme.Spacing.large),
            contentStack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Theme.Spacing.xLarge),
            contentStack.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: Theme.Spacing.large),
            contentStack.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -Theme.Spacing.large),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stateView.topAnchor.constraint(equalTo: view.topAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func configureImage() {
        productImageView.padding = Theme.Spacing.xLarge
        productImageView.isAccessibilityElement = true
    }

    private func configureLabels() {
        categoryLabel.font = Theme.Font.caption.bold()
        categoryLabel.textColor = Theme.Color.accent

        titleLabel.font = UIFont.preferredFont(forTextStyle: .title2).bold()
        titleLabel.textColor = Theme.Color.primaryText
        titleLabel.accessibilityTraits = .header

        priceLabel.font = UIFont.preferredFont(forTextStyle: .title3).bold()
        priceLabel.textColor = Theme.Color.primaryText

        ratingView.font = UIFont.preferredFont(forTextStyle: .subheadline)
        ratingView.isAccessibilityElement = true

        descriptionHeaderLabel.text = "Description"
        descriptionHeaderLabel.font = Theme.Font.sectionTitle
        descriptionHeaderLabel.textColor = Theme.Color.primaryText
        descriptionHeaderLabel.accessibilityTraits = .header

        descriptionLabel.font = Theme.Font.body
        descriptionLabel.textColor = Theme.Color.secondaryText

        [categoryLabel, titleLabel, priceLabel, descriptionHeaderLabel, descriptionLabel].forEach {
            $0.numberOfLines = 0
            $0.adjustsFontForContentSizeCategory = true
        }
    }

    private func configureBottomBar() {
        bottomBar.backgroundColor = Theme.Color.background
        bottomBar.translatesAutoresizingMaskIntoConstraints = false

        let separator = UIView()
        separator.backgroundColor = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false

        var configuration = UIButton.Configuration.filled()
        configuration.title = viewModel.enquireButtonTitle
        configuration.image = UIImage(systemName: "envelope")
        configuration.imagePadding = Theme.Spacing.small
        configuration.cornerStyle = .large
        configuration.buttonSize = .large
        enquireButton.configuration = configuration
        enquireButton.translatesAutoresizingMaskIntoConstraints = false
        enquireButton.addAction(UIAction { [weak self] _ in self?.viewModel.requestEnquiry() }, for: .primaryActionTriggered)

        bottomBar.addSubview(separator)
        bottomBar.addSubview(enquireButton)
        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: bottomBar.topAnchor),
            separator.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: Self.hairline),

            enquireButton.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: Theme.Spacing.medium),
            enquireButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: Theme.Spacing.large),
            enquireButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -Theme.Spacing.large),
            enquireButton.bottomAnchor.constraint(equalTo: bottomBar.safeAreaLayoutGuide.bottomAnchor, constant: -Theme.Spacing.small),
        ])
    }
}
