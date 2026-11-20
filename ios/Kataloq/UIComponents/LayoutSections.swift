import UIKit

/// Compositional-layout building blocks shared by Home, Category and Search.
enum LayoutSections {
    private static let estimatedCardHeight: CGFloat = 300

    /// Horizontally scrolling row of product cards, shopping-app style: snaps to each card and
    /// shows part of the next one so it's obvious the row scrolls.
    static func productCarousel() -> NSCollectionLayoutSection {
        let height = NSCollectionLayoutDimension.estimated(estimatedCardHeight)
        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: height)
        )
        // ~2.3 cards visible on any iPhone width.
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.43), heightDimension: height),
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
        section.interGroupSpacing = Theme.Spacing.large
        section.contentInsets = sectionInsets(horizontal: Theme.Spacing.large)
        section.boundarySupplementaryItems = [header()]
        return section
    }

    /// Two-column product grid with self-sizing rows.
    /// Each item is exactly half the width; spacing comes from item insets, so nothing can overflow.
    static func productGrid() -> NSCollectionLayoutSection {
        let height = NSCollectionLayoutDimension.estimated(estimatedCardHeight)
        let halfSpacing = Theme.Spacing.large / 2

        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: height)
        )
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: halfSpacing, bottom: 0, trailing: halfSpacing)

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: height),
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = Theme.Spacing.xLarge
        section.contentInsets = sectionInsets(horizontal: Theme.Spacing.large - halfSpacing)
        section.boundarySupplementaryItems = [header(horizontalInset: halfSpacing)]
        return section
    }

    /// Horizontally scrolling row of category chips.
    static func chipRow() -> NSCollectionLayoutSection {
        let size = NSCollectionLayoutSize(widthDimension: .estimated(140), heightDimension: .estimated(40))
        let item = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = Theme.Spacing.small
        section.contentInsets = sectionInsets(horizontal: Theme.Spacing.large)
        section.boundarySupplementaryItems = [header()]
        return section
    }

    static func header(horizontalInset: CGFloat = 0) -> NSCollectionLayoutBoundarySupplementaryItem {
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
        header.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: horizontalInset, bottom: 0, trailing: horizontalInset)
        return header
    }

    private static func sectionInsets(horizontal: CGFloat) -> NSDirectionalEdgeInsets {
        NSDirectionalEdgeInsets(top: Theme.Spacing.small, leading: horizontal, bottom: Theme.Spacing.xxLarge, trailing: horizontal)
    }
}
