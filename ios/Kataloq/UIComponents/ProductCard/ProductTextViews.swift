import UIKit

/// Product name: SF Pro Medium, up to two lines, tail-truncated. Always reserves two lines'
/// height (text top-aligned), so names, prices and ratings line up across cards.
final class ProductTitleView: UIView {
    private let label = UILabel()
    private lazy var heightConstraint = heightAnchor.constraint(equalToConstant: 0)
    private let lines: Int

    var text: String? {
        get { label.text }
        set { label.text = newValue }
    }

    var font: UIFont {
        get { label.font }
        set {
            label.font = newValue
            updateReservedHeight()
        }
    }

    /// - Parameter lines: Lines reserved and shown. `0` means unlimited, with no reserved height.
    init(lines: Int = Theme.ProductCard.titleLines) {
        self.lines = lines
        super.init(frame: .zero)

        label.font = Theme.Font.productTitle
        label.textColor = Theme.Color.primaryText
        label.numberOfLines = lines
        label.lineBreakMode = .byTruncatingTail
        label.adjustsFontForContentSizeCategory = true
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor),
            label.leadingAnchor.constraint(equalTo: leadingAnchor),
            label.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor),
        ])
        if lines > 0 {
            heightConstraint.isActive = true
            updateReservedHeight()
        } else {
            label.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
        }
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateReservedHeight() // Dynamic Type changes the line height
    }

    private func updateReservedHeight() {
        guard lines > 0 else { return }
        heightConstraint.constant = ceil(label.font.lineHeight * CGFloat(lines))
    }
}

/// Product price: bold, primary colour. The text arrives already formatted with the product's
/// own currency (`ProductFormatting.price`), so no currency symbol is hardcoded here.
final class ProductPriceView: UILabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        font = Theme.Font.productPrice
        textColor = Theme.Color.primaryText
        adjustsFontForContentSizeCategory = true
        numberOfLines = 1
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

/// Orange star, rating score and count, visually secondary to the price.
/// Unrated products show "No ratings yet" without a star.
final class ProductRatingView: UIView {
    private let starView = UIImageView(image: UIImage(systemName: "star.fill"))
    private let scoreLabel = UILabel()
    private let countLabel = UILabel()

    private(set) var isStarHidden = false

    var font: UIFont = Theme.Font.productRating {
        didSet {
            scoreLabel.font = font
            countLabel.font = font
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    /// Text currently shown, e.g. "4.6 (400)" or "No ratings yet".
    var displayedText: String {
        [scoreLabel.text, countLabel.isHidden ? nil : countLabel.text].compactMap { $0 }.joined(separator: " ")
    }

    func configure(score: String, count: String, isRated: Bool) {
        if isRated {
            scoreLabel.text = score
            countLabel.text = count
        } else {
            scoreLabel.text = "No ratings yet"
            countLabel.text = nil
        }
        starView.isHidden = !isRated
        countLabel.isHidden = !isRated
        isStarHidden = !isRated
    }

    private func setUpViews() {
        starView.tintColor = Theme.Color.rating
        starView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .small)
        starView.setContentHuggingPriority(.required, for: .horizontal)

        [scoreLabel, countLabel].forEach {
            $0.font = font
            $0.textColor = Theme.Color.secondaryText
            $0.adjustsFontForContentSizeCategory = true
        }

        let stack = UIStackView(arrangedSubviews: [starView, scoreLabel, countLabel])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
        ])
    }
}
