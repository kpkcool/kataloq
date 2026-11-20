import UIKit

/// Product tile in shopping-app style: a white rounded image tile, then title (always two lines'
/// worth of space), price and rating. Used by Home, Category and Search.
final class ProductCardCell: UICollectionViewCell {
    private let imageTile = UIView()
    private let imageView = UIImageView()
    private let titleContainer = UIView()
    private let titleLabel = UILabel()
    private let priceLabel = UILabel()
    private let starView = UIImageView(image: UIImage(systemName: "star.fill"))
    private let ratingLabel = UILabel()

    /// Exactly two lines tall, so cards in the same row line up whatever the title length.
    private lazy var titleHeight = titleContainer.heightAnchor.constraint(equalToConstant: 0)

    private var imageTask: Task<Void, Never>?
    private var representedImageURL: URL?

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
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.contentView.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
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
        titleHeight.constant = ceil(titleLabel.font.lineHeight * 2)
        priceLabel.text = item.priceText
        ratingLabel.text = item.ratingValueText
        starView.isHidden = !item.isRated
        accessibilityLabel = item.accessibilityLabel
        loadImage(from: item.imageURL, using: imageLoader)
    }

    // MARK: - Image

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
        imageView.image = UIImage(systemName: "photo")
    }

    // MARK: - Layout

    private func setUpViews() {
        isAccessibilityElement = true
        accessibilityTraits = .button

        imageTile.backgroundColor = Theme.Color.imageBackground
        imageTile.layer.cornerRadius = Theme.Radius.card
        imageTile.layer.cornerCurve = .continuous
        imageTile.layer.borderWidth = 1
        imageTile.layer.borderColor = Theme.Color.hairline.cgColor
        imageTile.clipsToBounds = true
        imageTile.translatesAutoresizingMaskIntoConstraints = false

        imageView.tintColor = Theme.Color.placeholderTint
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title1)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageTile.addSubview(imageView)

        titleLabel.font = Theme.Font.cardTitle
        titleLabel.textColor = Theme.Color.primaryText
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleContainer.addSubview(titleLabel)

        priceLabel.font = Theme.Font.price
        priceLabel.textColor = Theme.Color.primaryText

        starView.tintColor = Theme.Color.rating
        starView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .caption1)
        starView.setContentHuggingPriority(.required, for: .horizontal)
        ratingLabel.font = Theme.Font.caption
        ratingLabel.textColor = Theme.Color.secondaryText

        [titleLabel, priceLabel, ratingLabel].forEach { $0.adjustsFontForContentSizeCategory = true }

        let ratingRow = UIStackView(arrangedSubviews: [starView, ratingLabel])
        ratingRow.axis = .horizontal
        ratingRow.spacing = Theme.Spacing.xSmall
        ratingRow.alignment = .center

        let textStack = UIStackView(arrangedSubviews: [titleContainer, priceLabel, ratingRow])
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = Theme.Spacing.xSmall
        textStack.setCustomSpacing(Theme.Spacing.small, after: titleContainer)
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(imageTile)
        contentView.addSubview(textStack)

        let bottom = textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Theme.Spacing.xSmall)
        bottom.priority = .defaultHigh // lets the estimated height be replaced cleanly when the cell self-sizes

        let imageInset = Theme.Spacing.medium
        NSLayoutConstraint.activate([
            imageTile.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageTile.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageTile.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageTile.heightAnchor.constraint(equalTo: imageTile.widthAnchor),

            imageView.topAnchor.constraint(equalTo: imageTile.topAnchor, constant: imageInset),
            imageView.leadingAnchor.constraint(equalTo: imageTile.leadingAnchor, constant: imageInset),
            imageView.trailingAnchor.constraint(equalTo: imageTile.trailingAnchor, constant: -imageInset),
            imageView.bottomAnchor.constraint(equalTo: imageTile.bottomAnchor, constant: -imageInset),

            titleLabel.topAnchor.constraint(equalTo: titleContainer.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: titleContainer.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: titleContainer.trailingAnchor),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: titleContainer.bottomAnchor),
            titleContainer.widthAnchor.constraint(equalTo: textStack.widthAnchor),
            titleHeight,

            textStack.topAnchor.constraint(equalTo: imageTile.bottomAnchor, constant: Theme.Spacing.medium - 2),
            textStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            bottom,
        ])
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // Keep the two-line title box right after a Dynamic Type change, and refresh the
        // CGColor border, which doesn't follow light/dark mode automatically.
        titleHeight.constant = ceil(titleLabel.font.lineHeight * 2)
        imageTile.layer.borderColor = Theme.Color.hairline.cgColor
    }
}
