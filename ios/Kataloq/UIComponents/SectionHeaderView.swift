import UIKit

/// Section title for collection views ("Shop by category", "Top Rated", ...).
final class SectionHeaderView: UICollectionReusableView {
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = Theme.Font.sectionTitle
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = Theme.Color.primaryText
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: Theme.Spacing.small),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Theme.Spacing.small),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(title: String) {
        titleLabel.text = title
    }
}
