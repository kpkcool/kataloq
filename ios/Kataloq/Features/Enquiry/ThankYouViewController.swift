import UIKit

struct ThankYouContent: Equatable {
    let productTitle: String
    let replyEmail: String
    let enquiryID: String

    /// First block of the enquiry ID, upper-cased: easy to read out on the phone.
    var shortReference: String {
        let firstBlock = enquiryID.split(separator: "-").first.map(String.init) ?? enquiryID
        return firstBlock.uppercased()
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

    // MARK: - Layout

    private func setUpViews() {
        headingLabel.text = "Thank you!"
        headingLabel.font = UIFont.preferredFont(forTextStyle: .largeTitle).bold()
        headingLabel.textColor = Theme.Color.primaryText
        headingLabel.accessibilityTraits = .header

        let subtitleLabel = makeLabel(
            "Your enquiry has been sent to our sales team.",
            font: Theme.Font.body,
            color: Theme.Color.secondaryText
        )

        [headingLabel, subtitleLabel].forEach {
            $0.textAlignment = .center
            $0.numberOfLines = 0
            $0.adjustsFontForContentSizeCategory = true
        }

        let noteLabel = makeLabel(
            "We'll reply by email. Keep your reference in case you need to follow up.",
            font: Theme.Font.caption,
            color: Theme.Color.secondaryText
        )
        noteLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [makeSuccessBadge(), headingLabel, subtitleLabel, makeSummaryCard(), noteLabel])
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.small
        stack.setCustomSpacing(Theme.Spacing.xLarge, after: stack.arrangedSubviews[0])
        stack.setCustomSpacing(Theme.Spacing.xLarge, after: subtitleLabel)
        stack.setCustomSpacing(Theme.Spacing.large, after: stack.arrangedSubviews[3])
        stack.translatesAutoresizingMaskIntoConstraints = false

        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        let bottomBar = makeBottomBar()
        view.addSubview(scrollView)
        view.addSubview(bottomBar)

        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: Theme.Spacing.xxLarge + Theme.Spacing.large),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Theme.Spacing.xLarge),
            stack.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: Theme.Spacing.xLarge),
            stack.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -Theme.Spacing.xLarge),

            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    /// A green check inside a soft green circle, centred and kept at its natural size.
    private func makeSuccessBadge() -> UIView {
        let circle = UIView()
        circle.backgroundColor = Theme.Color.success.withAlphaComponent(0.14)
        circle.layer.cornerRadius = 48
        circle.translatesAutoresizingMaskIntoConstraints = false

        let check = UIImageView(image: UIImage(systemName: "checkmark"))
        check.tintColor = Theme.Color.success
        check.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 40, weight: .bold)
        check.contentMode = .center
        check.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(check)

        let container = UIView()
        container.isAccessibilityElement = false
        container.addSubview(circle)

        NSLayoutConstraint.activate([
            circle.widthAnchor.constraint(equalToConstant: 96),
            circle.heightAnchor.constraint(equalToConstant: 96),
            circle.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            circle.topAnchor.constraint(equalTo: container.topAnchor),
            circle.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            check.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            check.centerYAnchor.constraint(equalTo: circle.centerYAnchor),
        ])
        return container
    }

    /// Product, reply address and reference, on a rounded card.
    private func makeSummaryCard() -> UIView {
        let rows = [
            makeSummaryRow(label: "Product", value: content.productTitle),
            makeSummaryRow(label: "We'll reply to", value: content.replyEmail),
            makeSummaryRow(label: "Reference", value: content.shortReference, monospaced: true),
        ]

        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.medium
        stack.translatesAutoresizingMaskIntoConstraints = false
        for (index, row) in rows.enumerated() {
            stack.addArrangedSubview(row)
            if index < rows.count - 1 {
                stack.addArrangedSubview(makeSeparator())
            }
        }

        let card = UIView()
        card.backgroundColor = Theme.Color.cardBackground
        card.layer.cornerRadius = Theme.Radius.card + 2
        card.layer.cornerCurve = .continuous
        card.addSubview(stack)

        let padding = Theme.Spacing.large
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: padding),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -padding),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: padding),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -padding),
        ])
        return card
    }

    private func makeSummaryRow(label: String, value: String, monospaced: Bool = false) -> UIView {
        let labelView = makeLabel(label.uppercased(), font: Theme.Font.caption.bold(), color: Theme.Color.secondaryText)
        let valueFont = monospaced
            ? UIFontMetrics(forTextStyle: .body).scaledFont(for: .monospacedSystemFont(ofSize: 17, weight: .semibold))
            : UIFont.preferredFont(forTextStyle: .body)
        let valueView = makeLabel(value, font: valueFont, color: Theme.Color.primaryText)

        let row = UIStackView(arrangedSubviews: [labelView, valueView])
        row.axis = .vertical
        row.spacing = 2
        // One VoiceOver element per row: "Product, Fjallraven Backpack".
        row.isAccessibilityElement = true
        row.accessibilityLabel = "\(label), \(value)"
        return row
    }

    private func makeSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
        return separator
    }

    private func makeBottomBar() -> UIView {
        var configuration = UIButton.Configuration.filled()
        configuration.title = "Continue shopping"
        configuration.cornerStyle = .large
        configuration.buttonSize = .large
        let doneButton = UIButton(configuration: configuration)
        doneButton.addAction(UIAction { [weak self] _ in self?.onDone() }, for: .primaryActionTriggered)
        doneButton.translatesAutoresizingMaskIntoConstraints = false

        let bar = UIView()
        bar.backgroundColor = Theme.Color.background
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(doneButton)
        NSLayoutConstraint.activate([
            doneButton.topAnchor.constraint(equalTo: bar.topAnchor, constant: Theme.Spacing.medium),
            doneButton.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: Theme.Spacing.xLarge),
            doneButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -Theme.Spacing.xLarge),
            doneButton.bottomAnchor.constraint(equalTo: bar.safeAreaLayoutGuide.bottomAnchor, constant: -Theme.Spacing.small),
        ])
        return bar
    }

    private func makeLabel(_ text: String, font: UIFont, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = font
        label.textColor = color
        label.numberOfLines = 0
        label.adjustsFontForContentSizeCategory = true
        return label
    }
}
