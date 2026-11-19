import UIKit

/// Product tile: image, title, price, rating. Used by Home, Category and Search.
final class ProductCardCell: UICollectionViewCell {
    private let imageContainer = UIView()
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let titleContainer = UIView()
    private let priceLabel = UILabel()
    private let ratingLabel = UILabel()

    /// Reserves two lines for the title so every card in a row has the same height.
    private lazy var titleMinHeight = titleContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 0)
    private var imageTask: Task<Void, Never>?
    private var representedImageURL: URL?

    private static var placeholderImage: UIImage? {
        UIImage(systemName: "photo")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    deinit {
        imageTask?.cancel()
    }

    override var isHighlighted: Bool {
        didSet { contentView.alpha = isHighlighted ? 0.7 : 1 }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        imageTask = nil
        representedImageURL = nil
        showPlaceholder()
    }

    func configure(with item: ProductCardViewData, imageLoader: any ImageLoading) {
        titleLabel.text = item.title
        titleMinHeight.constant = ceil(titleLabel.font.lineHeight * 2)
        priceLabel.text = item.priceText
        ratingLabel.text = item.ratingText
        accessibilityLabel = item.accessibilityLabel
        loadImage(from: item.imageURL, using: imageLoader)
    }

    private func loadImage(from url: URL?, using imageLoader: any ImageLoading) {
        imageTask?.cancel()
        representedImageURL = url
        showPlaceholder()
        guard let url else { return }

        imageTask = Task { [weak self] in
            let image = await imageLoader.image(for: url)
            // The cell may have been reused for another product while the image loaded.
            guard let self, !Task.isCancelled, self.representedImageURL == url, let image else { return }
            self.imageView.contentMode = .scaleAspectFit
            self.imageView.image = image
        }
    }

    private func showPlaceholder() {
        imageView.contentMode = .center
        imageView.image = Self.placeholderImage
    }

    private func setUpViews() {
        contentView.backgroundColor = Theme.Color.cardBackground
        contentView.layer.cornerRadius = Theme.Radius.card
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true

        isAccessibilityElement = true
        accessibilityTraits = .button

        imageContainer.backgroundColor = Theme.Color.imageBackground
        imageContainer.layer.cornerRadius = Theme.Radius.card - 4
        imageContainer.clipsToBounds = true
        imageContainer.translatesAutoresizingMaskIntoConstraints = false

        imageView.tintColor = Theme.Color.placeholderTint
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title1)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageContainer.addSubview(imageView)

        titleLabel.font = Theme.Font.cardTitle
        titleLabel.textColor = Theme.Color.primaryText
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail

        priceLabel.font = Theme.Font.price
        priceLabel.textColor = Theme.Color.primaryText

        ratingLabel.font = Theme.Font.caption
        ratingLabel.textColor = Theme.Color.rating

        [titleLabel, priceLabel, ratingLabel].forEach { $0.adjustsFontForContentSizeCategory = true }

        // The title sits at the top of a container that's always at least two lines tall.
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleContainer.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: titleContainer.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: titleContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: titleContainer.trailingAnchor),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: titleContainer.bottomAnchor),
        ])

        let textStack = UIStackView(arrangedSubviews: [titleContainer, priceLabel, ratingLabel])
        textStack.axis = .vertical
        textStack.spacing = Theme.Spacing.xSmall
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(imageContainer)
        contentView.addSubview(textStack)

        let inset = Theme.Spacing.small
        NSLayoutConstraint.activate([
            imageContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: inset),
            imageContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: inset),
            imageContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -inset),
            imageContainer.heightAnchor.constraint(equalTo: imageContainer.widthAnchor),

            imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor, constant: inset),
            imageView.leadingAnchor.constraint(equalTo: imageContainer.leadingAnchor, constant: inset),
            imageView.trailingAnchor.constraint(equalTo: imageContainer.trailingAnchor, constant: -inset),
            imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor, constant: -inset),

            textStack.topAnchor.constraint(equalTo: imageContainer.bottomAnchor, constant: Theme.Spacing.small),
            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: inset),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -inset),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -inset),
            titleMinHeight,
        ])
    }
}
