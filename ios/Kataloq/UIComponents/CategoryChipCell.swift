import UIKit

/// A tappable category "pill" for the horizontal category row.
final class CategoryChipCell: UICollectionViewCell {
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
        accessibilityLabel = category.name
    }

    private func setUpViews() {
        contentView.backgroundColor = Theme.Color.chipBackground
        contentView.layer.cornerRadius = Theme.Radius.chip
        contentView.layer.cornerCurve = .continuous

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityHint = "Shows products in this category."

        titleLabel.font = Theme.Font.chip
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = Theme.Color.primaryText
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Theme.Spacing.small),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Theme.Spacing.small),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Theme.Spacing.large),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Theme.Spacing.large),
        ])
    }
}
