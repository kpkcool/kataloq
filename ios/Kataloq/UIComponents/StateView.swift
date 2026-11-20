import UIKit

/// Full-screen loading / empty / error-with-retry view, shared by every screen.
/// (iOS 16 has no UIContentUnavailableConfiguration, which arrived in iOS 17.)
final class StateView: UIView {
    enum Content: Equatable {
        case loading
        case message(String)
        case error(String)
    }

    /// Called when the user taps "Try again" in the error state.
    var onRetry: (() -> Void)?

    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let messageLabel = UILabel()
    private let retryButton = UIButton(configuration: .filled())
    private let stackView = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpViews()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(_ content: Content) {
        switch content {
        case .loading:
            activityIndicator.startAnimating()
            messageLabel.isHidden = true
            retryButton.isHidden = true
        case .message(let text):
            activityIndicator.stopAnimating()
            messageLabel.text = text
            messageLabel.isHidden = false
            retryButton.isHidden = true
        case .error(let text):
            activityIndicator.stopAnimating()
            messageLabel.text = text
            messageLabel.isHidden = false
            retryButton.isHidden = false
        }
        UIAccessibility.post(notification: .layoutChanged, argument: content == .loading ? activityIndicator : messageLabel)
    }

    private func setUpViews() {
        backgroundColor = Theme.Color.background

        activityIndicator.hidesWhenStopped = true
        activityIndicator.accessibilityLabel = "Loading"

        messageLabel.font = Theme.Font.body
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = Theme.Color.secondaryText
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.title = "Try again"
        buttonConfiguration.cornerStyle = .large
        retryButton.configuration = buttonConfiguration
        retryButton.addAction(UIAction { [weak self] _ in self?.onRetry?() }, for: .primaryActionTriggered)

        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = Theme.Spacing.large
        stackView.translatesAutoresizingMaskIntoConstraints = false
        [activityIndicator, messageLabel, retryButton].forEach(stackView.addArrangedSubview)
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: safeAreaLayoutGuide.centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: layoutMarginsGuide.leadingAnchor, constant: Theme.Spacing.large),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: layoutMarginsGuide.trailingAnchor, constant: -Theme.Spacing.large),
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
        ])
    }
}
