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

    enum Color {
        static var accent: UIColor { .systemIndigo }
        static var background: UIColor { .systemBackground }
        static var cardBackground: UIColor { .secondarySystemBackground }
        static var chipBackground: UIColor { .tertiarySystemFill }
        static var imageBackground: UIColor { .white }
        static var hairline: UIColor { .systemGray5 }
        static var success: UIColor { .systemGreen }
        static var placeholderTint: UIColor { .tertiaryLabel }
        static var primaryText: UIColor { .label }
        static var secondaryText: UIColor { .secondaryLabel }
        static var rating: UIColor { .systemOrange }
        static var error: UIColor { .systemRed }
    }

    /// Dynamic Type fonts: they scale with the user's text size setting.
    enum Font {
        static var sectionTitle: UIFont { .preferredFont(forTextStyle: .title3).bold() }
        static var cardTitle: UIFont { .preferredFont(forTextStyle: .subheadline) }
        static var price: UIFont { .preferredFont(forTextStyle: .headline) }
        static var caption: UIFont { .preferredFont(forTextStyle: .caption1) }
        static var body: UIFont { .preferredFont(forTextStyle: .body) }
        static var chip: UIFont { .preferredFont(forTextStyle: .subheadline) }
    }
}

extension UIFont {
    func bold() -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(.traitBold) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
