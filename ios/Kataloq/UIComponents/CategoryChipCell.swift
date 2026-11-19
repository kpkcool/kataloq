import UIKit

/// A tappable category "pill" with an icon, for the horizontal category row.
final class CategoryChipCell: UICollectionViewCell {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override var isHighlighted: Bool {
        didSet { contentView.alpha = isHighlighted ? 0.6 : 1 }
    }

    func configure(with category: ProductCategory) {
        titleLabel.text = category.name
        iconView.image = UIImage(systemName: CategoryIcon.symbolName(for: category))
        accessibilityLabel = category.name
    }

    private func setUpViews() {
        contentView.backgroundColor = Theme.Color.chipBackground
        contentView.layer.cornerRadius = Theme.Radius.chip
        contentView.layer.cornerCurve = .continuous

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityHint = "Shows products in this category."

        iconView.tintColor = Theme.Color.accent
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .subheadline)
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .horizontal)

        titleLabel.font = Theme.Font.chip
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = Theme.Color.primaryText

        let stack = UIStackView(arrangedSubviews: [iconView, titleLabel])
        stack.axis = .horizontal
        stack.spacing = Theme.Spacing.small
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Theme.Spacing.small + 2),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -(Theme.Spacing.small + 2)),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.large),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.large),
        ])
    }
}

/// Presentation-only mapping from category to an SF Symbol. Unknown categories (e.g. from a
/// future data source) get a generic tag icon, so nothing breaks when categories change.
enum CategoryIcon {
    static func symbolName(for category: ProductCategory) -> String {
        switch category.id {
        case "electronics": return "desktopcomputer"
        case "jewelery", "jewellery", "jewelry": return "sparkles"
        case "mens-clothing": return "tshirt"
        case "womens-clothing": return "handbag"
        default: return "tag"
        }
    }
}
