import UIKit

/// Enquiry form, presented modally: name, email, phone (optional), message (optional).
final class EnquiryViewController: UIViewController {
    private let viewModel: EnquiryViewModel

    private let scrollView = UIScrollView()
    private let productLabel = UILabel()
    private let errorBanner = UILabel()
    private let errorBannerView = UIView()
    private let submitButton = UIButton(configuration: .filled())

    private lazy var fields: [EnquiryField: FormFieldView] = [
        .name: FormFieldView(
            title: "Name",
            requirement: .required,
            kind: .singleLine(contentType: .name, keyboard: .default, capitalization: .words)
        ),
        .email: FormFieldView(
            title: "Email",
            requirement: .required,
            kind: .singleLine(contentType: .emailAddress, keyboard: .emailAddress, capitalization: .none)
        ),
        .phone: FormFieldView(
            title: "Phone",
            requirement: .optional,
            kind: .singleLine(contentType: .telephoneNumber, keyboard: .phonePad, capitalization: .none)
        ),
        .message: FormFieldView(title: "Message", requirement: .optional, kind: .multiLine),
    ]

    private let fieldOrder: [EnquiryField] = [.name, .email, .phone, .message]
    private var submitTask: Task<Void, Never>?

    init(viewModel: EnquiryViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        title = viewModel.title
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.Color.background
        navigationItem.largeTitleDisplayMode = .never
        let closeButton = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak self] _ in self?.viewModel.cancel() }
        )
        closeButton.accessibilityLabel = "Close"
        navigationItem.rightBarButtonItem = closeButton
        setUpViews()
        bindViewModel()
        render(viewModel.state)
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
        viewModel.onFieldErrorsChange = { [weak self] errors in
            self?.renderFieldErrors(errors)
        }
        for (field, fieldView) in fields {
            fieldView.onTextChange = { [weak self] text in
                self?.viewModel.update(field, to: text)
            }
        }
        // Return moves to the next field; on the last single-line field it submits.
        fields[.name]?.onReturn = { [weak self] in self?.fields[.email]?.focus() }
        fields[.email]?.onReturn = { [weak self] in self?.fields[.phone]?.focus() }
        fields[.phone]?.onReturn = { [weak self] in self?.fields[.message]?.focus() }
    }

    private func submit() {
        view.endEditing(true)
        let viewModel = self.viewModel
        submitTask = Task { await viewModel.submit() }
    }

    private func render(_ state: EnquiryState) {
        let isSubmitting = state == .submitting
        // Don't let a swipe dismiss the sheet while the request is in flight.
        isModalInPresentation = isSubmitting
        navigationController?.isModalInPresentation = isSubmitting
        navigationItem.rightBarButtonItem?.isEnabled = !isSubmitting
        fields.values.forEach { $0.isEnabled = !isSubmitting }

        var configuration = submitButton.configuration ?? .filled()
        configuration.showsActivityIndicator = isSubmitting
        configuration.title = isSubmitting ? "Sending…" : viewModel.submitButtonTitle
        submitButton.configuration = configuration
        submitButton.isEnabled = !isSubmitting

        if case .failed(let message) = state {
            errorBanner.text = message
            errorBannerView.isHidden = false
            UIAccessibility.post(notification: .announcement, argument: message)
        } else {
            errorBannerView.isHidden = true
        }
    }

    private func renderFieldErrors(_ errors: [EnquiryField: String]) {
        for (field, fieldView) in fields {
            fieldView.setError(errors[field])
        }
        // Move to and announce the first problem.
        if let first = fieldOrder.first(where: { errors[$0] != nil }), let message = errors[first] {
            fields[first]?.focus()
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    // MARK: - Layout

    /// Red-tinted rounded box with a warning icon; hidden until a submission fails.
    private func configureErrorBannerView() {
        errorBannerView.backgroundColor = Theme.Color.error.withAlphaComponent(0.1)
        errorBannerView.layer.cornerRadius = Theme.Radius.button
        errorBannerView.layer.cornerCurve = .continuous
        errorBannerView.isHidden = true

        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        icon.tintColor = Theme.Color.error
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .subheadline)
        icon.setContentHuggingPriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [icon, errorBanner])
        row.axis = .horizontal
        row.spacing = Theme.Spacing.small
        row.alignment = .firstBaseline
        row.translatesAutoresizingMaskIntoConstraints = false
        errorBannerView.addSubview(row)

        let padding = Theme.Spacing.medium
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: errorBannerView.topAnchor, constant: padding),
            row.bottomAnchor.constraint(equalTo: errorBannerView.bottomAnchor, constant: -padding),
            row.leadingAnchor.constraint(equalTo: errorBannerView.leadingAnchor, constant: padding),
            row.trailingAnchor.constraint(equalTo: errorBannerView.trailingAnchor, constant: -padding),
        ])
    }

    private func setUpViews() {
        let introLabel = UILabel()
        introLabel.text = "You're enquiring about"
        introLabel.font = Theme.Font.caption
        introLabel.textColor = Theme.Color.secondaryText
        introLabel.adjustsFontForContentSizeCategory = true

        productLabel.text = viewModel.productTitle
        productLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        productLabel.textColor = Theme.Color.primaryText
        productLabel.numberOfLines = 0
        productLabel.adjustsFontForContentSizeCategory = true

        let infoLabel = UILabel()
        infoLabel.text = "Leave your details and our sales team will get back to you."
        infoLabel.font = Theme.Font.body
        infoLabel.textColor = Theme.Color.secondaryText
        infoLabel.numberOfLines = 0
        infoLabel.adjustsFontForContentSizeCategory = true

        errorBanner.font = UIFont.preferredFont(forTextStyle: .subheadline)
        errorBanner.textColor = Theme.Color.primaryText
        errorBanner.numberOfLines = 0
        errorBanner.adjustsFontForContentSizeCategory = true
        configureErrorBannerView()

        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.title = viewModel.submitButtonTitle
        buttonConfiguration.cornerStyle = .large
        buttonConfiguration.buttonSize = .large
        buttonConfiguration.imagePadding = Theme.Spacing.small
        submitButton.configuration = buttonConfiguration
        submitButton.addAction(UIAction { [weak self] _ in self?.submit() }, for: .primaryActionTriggered)

        let header = UIStackView(arrangedSubviews: [introLabel, productLabel, infoLabel])
        header.axis = .vertical
        header.spacing = Theme.Spacing.xSmall
        header.setCustomSpacing(Theme.Spacing.medium, after: productLabel)

        let fieldViews: [UIView] = fieldOrder.compactMap { field -> UIView? in fields[field] }
        let stack = UIStackView(arrangedSubviews: [header] + fieldViews + [errorBannerView])
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.large + 2
        stack.setCustomSpacing(Theme.Spacing.xLarge, after: header)
        stack.translatesAutoresizingMaskIntoConstraints = false

        // "Send enquiry" stays at the bottom of the sheet, just above the home indicator, and rises
        // above the keyboard while typing, so it is always one tap away and never leaves a gap below.
        let bottomBar = UIView()
        bottomBar.backgroundColor = Theme.Color.background
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.addSubview(submitButton)
        view.addSubview(bottomBar)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        scrollView.addSubview(stack)
        view.addSubview(scrollView)

        let content = scrollView.contentLayoutGuide
        let frame = scrollView.frameLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            // The keyboard guide sits on the safe area when the keyboard is hidden.
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            submitButton.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: Theme.Spacing.medium),
            submitButton.bottomAnchor.constraint(equalTo: bottomBar.bottomAnchor, constant: -Theme.Spacing.small),
            submitButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: Theme.Spacing.large),
            submitButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -Theme.Spacing.large),

            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: Theme.Spacing.large),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Theme.Spacing.small),
            // The form always reaches down to the Send button: when there is spare height the
            // Message box takes it (lowest hugging priority), instead of leaving an empty gap.
            // With the keyboard up the Message box is back to its minimum and the form scrolls.
            stack.heightAnchor.constraint(
                greaterThanOrEqualTo: frame.heightAnchor,
                constant: -(Theme.Spacing.large + Theme.Spacing.small)
            ),
            stack.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: Theme.Spacing.large),
            stack.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -Theme.Spacing.large),
        ])
    }
}
