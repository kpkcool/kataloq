import Foundation

enum EnquiryState: Equatable {
    case editing
    case submitting
    /// Not sent. The form keeps everything the user typed so they can retry.
    case failed(message: String)
    case submitted(EnquiryConfirmation)
}

/// Enquiry form logic (FR-6/7/8): validate, submit once, and report success only when the
/// backend confirms the email was accepted (HTTP 202).
@MainActor
final class EnquiryViewModel {
    let title = "Enquiry"
    let submitButtonTitle = "Send enquiry"
    let productTitle: String

    private(set) var form = EnquiryForm()

    private(set) var fieldErrors: [EnquiryField: String] = [:] {
        didSet { onFieldErrorsChange?(fieldErrors) }
    }

    private(set) var state: EnquiryState = .editing {
        didSet { onStateChange?(state) }
    }

    var onStateChange: ((EnquiryState) -> Void)?
    var onFieldErrorsChange: (([EnquiryField: String]) -> Void)?

    // Navigation intents, handled by the coordinator.
    /// Confirmation and the (trimmed) email the sales team will reply to.
    var onSubmitted: ((EnquiryConfirmation, String) -> Void)?
    var onCancel: (() -> Void)?

    private let productID: String
    private let repository: any EnquiryRepository

    init(product: Product, repository: any EnquiryRepository) {
        productID = product.id
        productTitle = product.title
        self.repository = repository
    }

    var isSubmitting: Bool {
        state == .submitting
    }

    func update(_ field: EnquiryField, to value: String) {
        switch field {
        case .name: form.name = value
        case .email: form.email = value
        case .phone: form.phone = value
        case .message: form.message = value
        }
        // The user is fixing it: clear that field's error and any failure banner.
        if fieldErrors[field] != nil {
            fieldErrors[field] = nil
        }
        if case .failed = state {
            state = .editing
        }
    }

    func submit() async {
        // One submission at a time, and never resubmit after success (each submit sends an email).
        switch state {
        case .submitting, .submitted: return
        case .editing, .failed: break
        }

        let errors = EnquiryFormValidator.validate(form)
        guard errors.isEmpty else {
            fieldErrors = errors
            return
        }

        fieldErrors = [:]
        state = .submitting
        let request = EnquiryFormValidator.request(from: form, productID: productID)

        do {
            let confirmation = try await repository.submit(request)
            state = .submitted(confirmation)
            onSubmitted?(confirmation, request.email)
        } catch is CancellationError {
            state = .editing
        } catch {
            // The backend is authoritative: show its field errors inline when it sends them.
            let serverErrors = Self.fieldErrors(from: error)
            if serverErrors.isEmpty {
                state = .failed(message: UserFacingError.message(for: error))
            } else {
                fieldErrors = serverErrors
                state = .editing
            }
        }
    }

    func cancel() {
        onCancel?()
    }

    private static func fieldErrors(from error: Error) -> [EnquiryField: String] {
        guard case let .server(_, _, _, details)? = error as? APIError else { return [:] }
        var errors: [EnquiryField: String] = [:]
        for detail in details {
            if let field = EnquiryField(rawValue: detail.field) {
                errors[field] = detail.message
            }
        }
        return errors
    }
}
