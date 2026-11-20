import UIKit

/// Compositional-layout sections shared by Home, Category and Search.
/// All sizes come from `Theme.ProductCard`; nothing assumes a particular screen width.
enum LayoutSections {
    private typealias Tokens = Theme.ProductCard

    /// Height estimate for a product card of a given width, computed from the same tokens and
    /// fonts the card uses (square image + two reserved title lines + price + rating).
    ///
    /// Why it matters: a horizontal carousel's height is the tallest of its cards, and cards that
    /// haven't been scrolled into view yet only have their estimate. With a fixed guess (300 pt)
    /// the row first reserved too much height and then shrank while the user scrolled, moving
    /// everything below it. Keeping the estimate a few points *under* the real height means the
    /// first measured card always decides the row height, so it never changes while scrolling.
    static func estimatedCardHeight(forWidth width: CGFloat) -> CGFloat {
        let imageSide = width - 2 * Tokens.imageInset
        let title = ceil(Theme.Font.productTitle.lineHeight * CGFloat(Tokens.titleLines))
        let price = ceil(Theme.Font.productPrice.lineHeight)
        let rating = ceil(Theme.Font.productRating.lineHeight)
        let height = Tokens.imageInset + imageSide
            + Tokens.imageToTitleSpacing + title
            + Tokens.titleToPriceSpacing + price
            + Tokens.priceToRatingSpacing + rating
            + Tokens.bottomInset
        return (height - 4).rounded(.down)
    }

    /// Featured-style carousel: horizontally scrolling, snapping to each card. Card width is
    /// worked out from the container so two full cards and 30% of the next are visible on any
    /// iPhone, an intentional peek rather than an accidental-looking sliver.
    static func productCarousel(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let available = environment.container.effectiveContentSize.width
        let widthForPeek = (available - Tokens.screenPadding - 2 * Tokens.carouselSpacing) / (2 + Tokens.carouselPeekFraction)
        let cardWidth = min(
            max(widthForPeek, Tokens.carouselWidthRange.lowerBound),
            Tokens.carouselWidthRange.upperBound
        ).rounded(.down)

        let height = NSCollectionLayoutDimension.estimated(estimatedCardHeight(forWidth: cardWidth))
        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: height)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .absolute(cardWidth), heightDimension: height),
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
        section.interGroupSpacing = Tokens.carouselSpacing
        section.contentInsets = sectionInsets(horizontal: Tokens.screenPadding)
        section.boundarySupplementaryItems = [header()]
        return section
    }

    /// Standard-style grid: two equal columns with the same gap between columns and rows.
    /// Each item is exactly half the width and the gap comes from item insets, so cards can
    /// never overflow the screen.
    static func productGrid(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let halfGutter = Tokens.gridSpacing / 2
        let available = environment.container.effectiveContentSize.width
        let cardWidth = (available - 2 * Tokens.screenPadding - Tokens.gridSpacing) / 2
        let height = NSCollectionLayoutDimension.estimated(estimatedCardHeight(forWidth: cardWidth))

        let item = NSCollectionLayoutItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.5), heightDimension: height)
        )
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: halfGutter, bottom: 0, trailing: halfGutter)

        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: height),
            subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = Tokens.gridSpacing
        section.contentInsets = sectionInsets(horizontal: Tokens.screenPadding - halfGutter)
        section.boundarySupplementaryItems = [header(horizontalInset: halfGutter)]
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
        section.contentInsets = sectionInsets(horizontal: Tokens.screenPadding)
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

    /// The top and bottom insets also leave room for the card shadow: a carousel scrolls
    /// inside its own clipping scroll view, so without them the shadow would be cut off.
    private static func sectionInsets(horizontal: CGFloat) -> NSDirectionalEdgeInsets {
        NSDirectionalEdgeInsets(
            top: Theme.Spacing.small + 2,
            leading: horizontal,
            bottom: Tokens.sectionBottomSpacing,
            trailing: horizontal
        )
    }
}
