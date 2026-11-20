import UIKit

/// Central styling. The brief expects the look and feel to change, so screens never
/// hardcode colours, fonts or spacing: a reskin starts here.
enum Theme {
    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let xLarge: CGFloat = 24
        static let xxLarge: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 14
        static let chip: CGFloat = 18
        static let button: CGFloat = 12
    }

    /// Light Mode uses the product design spec's exact values; Dark Mode falls back to the
    /// matching system colours so text stays readable. Image tiles stay white in both modes,
    /// because product photos have white backgrounds.
    enum Color {
        static var accent: UIColor { .systemIndigo }
        static var background: UIColor { .dynamic(light: UIColor(hex: 0xFFFFFF), dark: .systemBackground) }
        static var cardBackground: UIColor { .secondarySystemBackground }
        /// Product card surface: white in Light Mode, a raised grey in Dark Mode.
        static var productCardSurface: UIColor { .dynamic(light: UIColor(hex: 0xFFFFFF), dark: .secondarySystemBackground) }
        static var chipBackground: UIColor { .tertiarySystemFill }
        static var imageBackground: UIColor { UIColor(hex: 0xFFFFFF) }
        static var hairline: UIColor { .dynamic(light: UIColor(hex: 0xEAEAEA), dark: .systemGray4) }
        static var success: UIColor { .systemGreen }
        static var placeholderTint: UIColor { .tertiaryLabel }
        static var primaryText: UIColor { .dynamic(light: UIColor(hex: 0x171717), dark: .label) }
        static var secondaryText: UIColor { .dynamic(light: UIColor(hex: 0x858585), dark: .secondaryLabel) }
        static var rating: UIColor { UIColor(hex: 0xF28C38) }
        static var error: UIColor { .systemRed }
    }

    /// Dynamic Type fonts: they scale with the user's text size setting.
    enum Font {
        static var sectionTitle: UIFont { .preferredFont(forTextStyle: .title3).bold() }
        /// SF Pro Medium 15 pt, scaled for Dynamic Type.
        static var productTitle: UIFont { scaled(.systemFont(ofSize: 15, weight: .medium), as: .subheadline) }
        /// SF Pro Bold 18 pt, scaled for Dynamic Type.
        static var productPrice: UIFont { scaled(.systemFont(ofSize: 18, weight: .bold), as: .headline) }
        /// SF Pro Regular 13 pt, scaled for Dynamic Type.
        static var productRating: UIFont { scaled(.systemFont(ofSize: 13, weight: .regular), as: .footnote) }
        static var caption: UIFont { .preferredFont(forTextStyle: .caption1) }
        static var body: UIFont { .preferredFont(forTextStyle: .body) }
        static var chip: UIFont { .preferredFont(forTextStyle: .subheadline) }

        private static func scaled(_ font: UIFont, as style: UIFont.TextStyle) -> UIFont {
            UIFontMetrics(forTextStyle: style).scaledFont(for: font)
        }
    }

    /// Product card design tokens, shared by the featured carousel, the grids and Product detail.
    enum ProductCard {
        // Card surface: white, rounded, hairline border, soft shadow.
        static let cornerRadius: CGFloat = 20
        static let borderWidth: CGFloat = 1
        /// Space between the card edge and the image tile.
        static let imageInset: CGFloat = 8
        /// Horizontal padding for the title, price and rating.
        static let textInset: CGFloat = 12
        static let bottomInset: CGFloat = 14

        /// One shadow for every product card: soft, diffuse, barely there.
        enum Shadow {
            static let opacity: Float = 0.06
            static let radius: CGFloat = 10
            static let offset = CGSize(width: 0, height: 3)
        }

        // Image tile inside the card.
        static let imageCornerRadius: CGFloat = 16
        static let imageBorderWidth: CGFloat = 1
        /// Photo padding inside the white tile, per card style.
        static let featuredImagePadding: CGFloat = 14
        static let standardImagePadding: CGFloat = 12

        static let titleLines = 2
        static let imageToTitleSpacing: CGFloat = 12
        static let titleToPriceSpacing: CGFloat = 8
        static let priceToRatingSpacing: CGFloat = 4

        /// Carousel cards are sized so two full cards and 30% of the third are visible: an
        /// obvious "scroll for more" peek rather than a sliver that looks clipped.
        static let carouselPeekFraction: CGFloat = 0.3
        static let carouselWidthRange: ClosedRange<CGFloat> = 140...200
        static let carouselSpacing: CGFloat = 14
        /// Same gap between columns and rows.
        static let gridSpacing: CGFloat = 14
        static let screenPadding: CGFloat = 16
        static let sectionBottomSpacing: CGFloat = 32
    }
}

extension UIColor {
    /// 0xRRGGBB, fully opaque.
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

    /// A colour that switches between Light and Dark Mode.
    static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark.resolvedColor(with: traits) : light.resolvedColor(with: traits)
        }
    }
}

extension UIFont {
    func bold() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
