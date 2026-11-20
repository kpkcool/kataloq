import UIKit

/// Enquiry form, presented modally: name, email, phone (optional), message (optional).
final class EnquiryViewController: UIViewController {
    private let viewModel: EnquiryViewModel

    private let scrollView = UIScrollView()
    private let productLabel = UILabel()
    private let errorBanner = UILabel()
    private let submitButton = UIButton(configuration: .filled())

    private lazy var fields: [EnquiryField: FormFieldView] = [
        .name: FormFieldView(
            title: "Name (required)",
            kind: .singleLine(contentType: .name, keyboard: .default, capitalization: .words)
        ),
        .email: FormFieldView(
            title: "Email (required)",
            kind: .singleLine(contentType: .emailAddress, keyboard: .emailAddress, capitalization: .none)
        ),
        .phone: FormFieldView(
            title: "Phone (optional)",
            kind: .singleLine(contentType: .telephoneNumber, keyboard: .phonePad, capitalization: .none)
        ),
        .message: FormFieldView(title: "Message (optional)", kind: .multiLine),
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
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in self?.viewModel.cancel() }
        )
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
        navigationItem.leftBarButtonItem?.isEnabled = !isSubmitting
        fields.values.forEach { $0.isEnabled = !isSubmitting }

        var configuration = submitButton.configuration ?? .filled()
        configuration.showsActivityIndicator = isSubmitting
        configuration.title = isSubmitting ? "Sending…" : viewModel.submitButtonTitle
        submitButton.configuration = configuration
        submitButton.isEnabled = !isSubmitting

        if case .failed(let message) = state {
            errorBanner.text = message
            errorBanner.isHidden = false
            UIAccessibility.post(notification: .announcement, argument: message)
        } else {
            errorBanner.isHidden = true
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
        errorBanner.textColor = Theme.Color.error
        errorBanner.numberOfLines = 0
        errorBanner.adjustsFontForContentSizeCategory = true
        errorBanner.isHidden = true

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
        let stack = UIStackView(arrangedSubviews: [header] + fieldViews + [errorBanner, submitButton])
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.large
        stack.setCustomSpacing(Theme.Spacing.xLarge, after: header)
        stack.translatesAutoresizingMaskIntoConstraints = false

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
            // Shrinks with the keyboard so the focused field and button stay reachable.
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: Theme.Spacing.large),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -Theme.Spacing.xLarge),
            stack.leadingAnchor.constraint(equalTo: frame.leadingAnchor, constant: Theme.Spacing.large),
            stack.trailingAnchor.constraint(equalTo: frame.trailingAnchor, constant: -Theme.Spacing.large),
        ])
    }
}
