import UIKit

struct ThankYouContent: Equatable {
    let productTitle: String
    let replyEmail: String
    let enquiryID: String

    var message: String {
        "Your enquiry about \u{201C}\(productTitle)\u{201D} has been sent. Our sales team will reply to \(replyEmail)."
    }

    var reference: String {
        "Reference: \(enquiryID)"
    }
}

/// Shown only after the backend confirmed the enquiry email was accepted (FR-8).
/// Static content with a single action, so it takes a value and a closure instead of a ViewModel.
final class ThankYouViewController: UIViewController {
    private let content: ThankYouContent
    private let onDone: () -> Void
    private let headingLabel = UILabel()

    init(content: ThankYouContent, onDone: @escaping () -> Void) {
        self.content = content
        self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
        title = "Enquiry sent"
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        navigationItem.hidesBackButton = true
        navigationItem.largeTitleDisplayMode = .never
        setUpViews()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIAccessibility.post(notification: .screenChanged, argument: headingLabel)
    }

    private func setUpViews() {
        let icon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        icon.tintColor = .systemGreen
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 72, weight: .regular)
        icon.isAccessibilityElement = false

        headingLabel.text = "Thank you!"
        headingLabel.font = UIFont.preferredFont(forTextStyle: .largeTitle).bold()
        headingLabel.accessibilityTraits = .header

        let messageLabel = UILabel()
        messageLabel.text = content.message
        messageLabel.font = Theme.Font.body
        messageLabel.textColor = Theme.Color.secondaryText

        let referenceLabel = UILabel()
        referenceLabel.text = content.reference
        referenceLabel.font = Theme.Font.caption
        referenceLabel.textColor = Theme.Color.secondaryText

        [headingLabel, messageLabel, referenceLabel].forEach {
            $0.numberOfLines = 0
            $0.textAlignment = .center
            $0.adjustsFontForContentSizeCategory = true
        }

        var configuration = UIButton.Configuration.filled()
        configuration.title = "Done"
        configuration.cornerStyle = .large
        configuration.buttonSize = .large
        let doneButton = UIButton(configuration: configuration)
        doneButton.addAction(UIAction { [weak self] _ in self?.onDone() }, for: .primaryActionTriggered)

        let stack = UIStackView(arrangedSubviews: [icon, headingLabel, messageLabel, referenceLabel, doneButton])
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = Theme.Spacing.medium
        stack.setCustomSpacing(Theme.Spacing.large, after: icon)
        stack.setCustomSpacing(Theme.Spacing.xLarge, after: referenceLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor, constant: Theme.Spacing.large),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor, constant: -Theme.Spacing.large),
        ])
    }
}
