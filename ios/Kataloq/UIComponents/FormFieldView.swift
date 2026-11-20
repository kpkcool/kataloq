import UIKit

/// A labelled form input with an inline error: single-line (UITextField) or multi-line (UITextView).
final class FormFieldView: UIView, UITextFieldDelegate, UITextViewDelegate {
    /// Shown next to the title: a red "*" for required, a light-grey "(optional)" for optional.
    enum Requirement {
        case required
        case optional

        var spokenText: String {
            switch self {
            case .required: return "required"
            case .optional: return "optional"
            }
        }
    }

    enum Kind {
        case singleLine(contentType: UITextContentType?, keyboard: UIKeyboardType, capitalization: UITextAutocapitalizationType)
        case multiLine
    }

    var onTextChange: ((String) -> Void)?
    /// Single-line fields: called when the user taps the return key.
    var onReturn: (() -> Void)?

    private let titleLabel = UILabel()
    private let errorLabel = UILabel()
    private let inputContainer = UIView()
    private var textField: UITextField?
    private var textView: UITextView?
    private let fieldTitle: String
    private let requirement: Requirement
    /// What VoiceOver reads for the input, e.g. "Name, required".
    private var spokenTitle: String { "\(fieldTitle), \(requirement.spokenText)" }

    init(title: String, requirement: Requirement, kind: Kind, returnKey: UIReturnKeyType = .next) {
        fieldTitle = title
        self.requirement = requirement
        super.init(frame: .zero)
        setUpViews(kind: kind, returnKey: returnKey)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    var text: String {
        textField?.text ?? textView?.text ?? ""
    }

    var isEnabled: Bool = true {
        didSet {
            textField?.isEnabled = isEnabled
            textView?.isEditable = isEnabled
            alpha = isEnabled ? 1 : 0.6
        }
    }

    @discardableResult
    func focus() -> Bool {
        if let textField {
            return textField.becomeFirstResponder()
        }
        return textView?.becomeFirstResponder() ?? false
    }

    func setError(_ message: String?) {
        errorLabel.text = message
        errorLabel.isHidden = message == nil
        inputContainer.layer.borderColor = (message == nil ? UIColor.separator : Theme.Color.error).cgColor
        inputContainer.layer.borderWidth = message == nil ? 0.5 : 1.5
        // VoiceOver reads the problem together with the field.
        textField?.accessibilityHint = message
        textView?.accessibilityHint = message
    }

    // MARK: - Setup

    private func setUpViews(kind: Kind, returnKey: UIReturnKeyType) {
        titleLabel.attributedText = makeTitle()
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.isAccessibilityElement = false // the input carries the label

        errorLabel.font = Theme.Font.caption
        errorLabel.textColor = Theme.Color.error
        errorLabel.numberOfLines = 0
        errorLabel.adjustsFontForContentSizeCategory = true
        errorLabel.isHidden = true

        inputContainer.backgroundColor = Theme.Color.cardBackground
        inputContainer.layer.cornerRadius = Theme.Radius.button
        inputContainer.layer.cornerCurve = .continuous
        inputContainer.layer.borderColor = UIColor.separator.cgColor
        inputContainer.layer.borderWidth = 0.5

        let input: UIView
        switch kind {
        case let .singleLine(contentType, keyboard, capitalization):
            let field = UITextField()
            field.textContentType = contentType
            field.keyboardType = keyboard
            field.autocapitalizationType = capitalization
            field.autocorrectionType = .no
            field.returnKeyType = returnKey
            field.font = Theme.Font.body
            field.adjustsFontForContentSizeCategory = true
            field.accessibilityLabel = spokenTitle
            field.delegate = self
            field.addAction(UIAction { [weak self, weak field] _ in
                self?.onTextChange?(field?.text ?? "")
            }, for: .editingChanged)
            field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
            textField = field
            input = field
        case .multiLine:
            let textArea = UITextView()
            textArea.font = Theme.Font.body
            textArea.adjustsFontForContentSizeCategory = true
            textArea.backgroundColor = .clear
            textArea.isScrollEnabled = false
            textArea.textContainerInset = UIEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
            textArea.textContainer.lineFragmentPadding = 0
            textArea.accessibilityLabel = spokenTitle
            textArea.delegate = self
            textArea.heightAnchor.constraint(greaterThanOrEqualToConstant: 110).isActive = true
            // The text area is the one view in a form that may grow to use spare height
            // (forms pin it to fill the screen down to their button).
            textArea.setContentHuggingPriority(.defaultLow - 1, for: .vertical)
            textView = textArea
            input = textArea
        }

        input.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(input)
        NSLayoutConstraint.activate([
            input.topAnchor.constraint(equalTo: inputContainer.topAnchor),
            input.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor),
            input.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: Theme.Spacing.medium),
            input.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -Theme.Spacing.medium),
        ])

        let stack = UIStackView(arrangedSubviews: [titleLabel, inputContainer, errorLabel])
        stack.axis = .vertical
        stack.spacing = Theme.Spacing.xSmall + 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    private func makeTitle() -> NSAttributedString {
        let titleFont = UIFont.preferredFont(forTextStyle: .subheadline).bold()
        let title = NSMutableAttributedString(
            string: fieldTitle,
            attributes: [.font: titleFont, .foregroundColor: Theme.Color.primaryText]
        )
        switch requirement {
        case .required:
            title.append(NSAttributedString(
                string: " *",
                attributes: [.font: titleFont, .foregroundColor: Theme.Color.error]
            ))
        case .optional:
            title.append(NSAttributedString(
                string: " (optional)",
                attributes: [
                    .font: UIFont.preferredFont(forTextStyle: .subheadline),
                    .foregroundColor: Theme.Color.secondaryText,
                ]
            ))
        }
        return title
    }

    // MARK: - Delegates

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        onReturn?()
        return false
    }

    func textViewDidChange(_ textView: UITextView) {
        onTextChange?(textView.text)
    }
}
