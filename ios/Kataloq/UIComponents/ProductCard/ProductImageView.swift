import UIKit

/// A product image on a white tile with a light-grey border and rounded corners.
/// The photo is aspect-fit inside fixed padding, so it is never stretched or cropped.
///
/// It loads its own image through the injected `ImageLoading`, cancels obsolete loads on reuse,
/// and ignores a result that arrives for a URL it no longer shows (fast scrolling).
final class ProductImageView: UIView {
    enum LoadingState: Equatable {
        case loading
        case loaded
        /// No URL, or the download failed.
        case unavailable
    }

    private(set) var loadingState: LoadingState = .loading
    /// The current load, internal so tests can await it.
    private(set) var loadTask: Task<Void, Never>?

    private let imageView = UIImageView()
    private var paddingConstraints: [NSLayoutConstraint] = []
    private var representedURL: URL?

    /// Space between the tile's edge and the photo.
    var padding: CGFloat = Theme.ProductCard.standardImagePadding {
        didSet {
            guard padding != oldValue else { return }
            paddingConstraints.forEach { $0.constant = $0.firstAttribute == .top || $0.firstAttribute == .leading ? padding : -padding }
        }
    }

    /// - Parameter aspectRatio: height ÷ width. Product cards use 1 (square).
    init(aspectRatio: CGFloat = 1) {
        super.init(frame: .zero)
        setUpViews(aspectRatio: aspectRatio)
        show(.loading)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    deinit {
        loadTask?.cancel()
    }

    // MARK: - Loading

    func load(_ url: URL?, using imageLoader: any ImageLoading) {
        cancel()
        representedURL = url
        guard let url else {
            show(.unavailable)
            return
        }
        show(.loading)

        loadTask = Task { [weak self] in
            let image = await imageLoader.image(for: url)
            guard let self, !Task.isCancelled, self.representedURL == url else { return }
            if let image {
                self.imageView.contentMode = .scaleAspectFit
                self.imageView.tintColor = nil
                self.imageView.image = image
                self.loadingState = .loaded
                self.accessibilityLabel = "Product image"
            } else {
                self.show(.unavailable)
            }
        }
    }

    /// Cancels any load and returns to the loading placeholder (call from `prepareForReuse`).
    func reset() {
        cancel()
        representedURL = nil
        show(.loading)
    }

    private func cancel() {
        loadTask?.cancel()
        loadTask = nil
    }

    /// Placeholder while loading (light photo symbol) and fallback when unavailable (darker symbol).
    private func show(_ state: LoadingState) {
        loadingState = state
        imageView.contentMode = .center
        imageView.image = UIImage(systemName: "photo")
        switch state {
        case .loading:
            imageView.tintColor = Theme.Color.hairline
            accessibilityLabel = "Loading image"
        case .unavailable:
            imageView.tintColor = Theme.Color.placeholderTint
            accessibilityLabel = "Image unavailable"
        case .loaded:
            break
        }
    }

    // MARK: - Layout

    private func setUpViews(aspectRatio: CGFloat) {
        backgroundColor = Theme.Color.imageBackground
        layer.cornerRadius = Theme.ProductCard.imageCornerRadius
        layer.cornerCurve = .continuous
        layer.borderWidth = Theme.ProductCard.imageBorderWidth
        layer.borderColor = Theme.Color.hairline.cgColor
        clipsToBounds = true

        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title1)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(imageView)

        paddingConstraints = [
            imageView.topAnchor.constraint(equalTo: topAnchor, constant: padding),
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: padding),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -padding),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -padding),
        ]
        NSLayoutConstraint.activate(paddingConstraints + [
            heightAnchor.constraint(equalTo: widthAnchor, multiplier: aspectRatio),
        ])
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        // CGColor borders don't follow Light/Dark Mode automatically.
        layer.borderColor = Theme.Color.hairline.cgColor
    }
}
