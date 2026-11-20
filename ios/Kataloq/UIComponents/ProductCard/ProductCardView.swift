import UIKit

/// The two presentations of a product card. They share every component and token; only
/// metrics differ. The section decides the style, not the product (Home shows the same
/// product as a featured and as a standard card).
enum ProductCardStyle: Equatable {
    /// Horizontal carousels: Home "Featured", Category "Top Rated".
    case featured
    /// Two-column grids: Home and Category "All Products", Search results.
    case standard

    var imagePadding: CGFloat {
        switch self {
        case .featured: return Theme.ProductCard.featuredImagePadding
        case .standard: return Theme.ProductCard.standardImagePadding
        }
    }
}

/// A product card: a white rounded surface with a hairline border and a soft shadow, holding
/// a square image tile, a two-line name, the price and the rating.
///
/// Two layers, because a view can't both clip to rounded corners and draw a shadow outside them:
/// - this view draws only the shadow (`masksToBounds` off, explicit `shadowPath`, so Core Animation
///   doesn't have to work the shape out from the content on every frame);
/// - `surfaceView` is rounded, bordered and clips its content.
///
/// Pure presentation: it renders a `ProductCardViewData` built by a ViewModel. It makes no
/// API calls, holds no business logic and knows nothing about navigation (taps are handled
/// by the collection view and forwarded to the ViewModel).
final class ProductCardView: UIView {
    private typealias Tokens = Theme.ProductCard

    let surfaceView = UIView()
    let imageView = ProductImageView()
    let titleView = ProductTitleView()
    let priceView = ProductPriceView()
    let ratingView = ProductRatingView()

    private(set) var style: ProductCardStyle = .standard
    private var shadowPathBounds: CGRect = .null

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(with item: ProductCardViewData, style: ProductCardStyle, imageLoader: any ImageLoading) {
        self.style = style
        imageView.padding = style.imagePadding
        titleView.text = item.title
        priceView.text = item.priceText
        ratingView.configure(score: item.ratingScoreText, count: item.ratingCountText, isRated: item.isRated)
        accessibilityLabel = item.accessibilityLabel
        imageView.load(item.imageURL, using: imageLoader)
    }

    /// Call from the hosting cell's `prepareForReuse`: cancels the image load so a recycled
    /// card can never show the previous product's image.
    func prepareForReuse() {
        imageView.reset()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Rebuild the shadow path only when the size actually changes, not on every layout pass.
        guard bounds != shadowPathBounds else { return }
        shadowPathBounds = bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: Tokens.cornerRadius).cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // CGColors don't follow Light/Dark Mode automatically.
        surfaceView.layer.borderColor = Theme.Color.hairline.cgColor
    }

    private func setUpViews() {
        isAccessibilityElement = true
        accessibilityTraits = .button

        backgroundColor = .clear
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = Tokens.Shadow.opacity
        layer.shadowRadius = Tokens.Shadow.radius
        layer.shadowOffset = Tokens.Shadow.offset

        surfaceView.backgroundColor = Theme.Color.productCardSurface
        surfaceView.layer.cornerRadius = Tokens.cornerRadius
        surfaceView.layer.cornerCurve = .continuous
        surfaceView.layer.borderWidth = Tokens.borderWidth
        surfaceView.layer.borderColor = Theme.Color.hairline.cgColor
        surfaceView.clipsToBounds = true
        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(surfaceView)

        let textStack = UIStackView(arrangedSubviews: [titleView, priceView, ratingView])
        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.setCustomSpacing(Tokens.titleToPriceSpacing, after: titleView)
        textStack.setCustomSpacing(Tokens.priceToRatingSpacing, after: priceView)

        [imageView, textStack].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            surfaceView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            surfaceView.topAnchor.constraint(equalTo: topAnchor),
            surfaceView.leadingAnchor.constraint(equalTo: leadingAnchor),
            surfaceView.trailingAnchor.constraint(equalTo: trailingAnchor),
            surfaceView.bottomAnchor.constraint(equalTo: bottomAnchor),

            imageView.topAnchor.constraint(equalTo: surfaceView.topAnchor, constant: Tokens.imageInset),
            imageView.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor, constant: Tokens.imageInset),
            imageView.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor, constant: -Tokens.imageInset),

            textStack.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: Tokens.imageToTitleSpacing),
            textStack.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor, constant: Tokens.textInset),
            textStack.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor, constant: -Tokens.textInset),
            textStack.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor, constant: -Tokens.bottomInset),
        ])
    }
}

/// Collection view cell hosting a `ProductCardView`. One cell type for every product listing;
/// the screen passes the style per section.
final class ProductCardCell: UICollectionViewCell {
    let cardView = ProductCardView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)

        // Slightly below required, so the estimated cell height can give way while self-sizing.
        let bottom = cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        bottom.priority = .required - 1
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            bottom,
        ])

        // The whole card is one VoiceOver element and one tap target.
        isAccessibilityElement = true
        accessibilityTraits = .button
        cardView.isAccessibilityElement = false
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.cardView.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        cardView.prepareForReuse()
    }

    func configure(with item: ProductCardViewData, style: ProductCardStyle, imageLoader: any ImageLoading) {
        cardView.configure(with: item, style: style, imageLoader: imageLoader)
        accessibilityLabel = item.accessibilityLabel
    }
}
