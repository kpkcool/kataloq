import UIKit

/// Compositional-layout building blocks shared by Home, Category and Search.
enum LayoutSections {
    /// Two-column product grid with self-sizing rows (works for any iPhone width and text size).
    static func productGrid(withHeader: Bool = true) -> NSCollectionLayoutSection {
        let estimatedHeight = NSCollectionLayoutDimension.estimated(280)
        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: estimatedHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: estimatedHeight),
            repeatingSubitem: item,
            count: 2
        )
        group.interItemSpacing = .fixed(Theme.Spacing.medium)

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = Theme.Spacing.medium
        section.contentInsets = NSDirectionalEdgeInsets(
            top: Theme.Spacing.small, leading: Theme.Spacing.large,
            bottom: Theme.Spacing.xLarge, trailing: Theme.Spacing.large
        )
        if withHeader {
            section.boundarySupplementaryItems = [header()]
        }
        return section
    }

    static func header() -> NSCollectionLayoutBoundarySupplementaryItem {
        NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(44)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )
    }
}
