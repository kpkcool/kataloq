import Foundation

enum EnquiryField: String, CaseIterable, Hashable {
    // Raw values match the backend's `details[].field`, so server errors map straight onto fields.
    case name, email, phone, message
}

struct EnquiryForm: Equatable {
    var name = ""
    var email = ""
    var phone = ""
    var message = ""
}

/// Client-side copy of the backend's enquiry rules (backend/src/domain/enquiry.ts), for instant
/// feedback. The backend stays authoritative: its 400 field errors are shown the same way.
enum EnquiryFormValidator {
    static let nameLength = 2...100
    static let emailMaxLength = 254
    static let phoneDigits = 6...15
    static let messageMaxLength = 1000

    static func validate(_ form: EnquiryForm) -> [EnquiryField: String] {
        var errors: [EnquiryField: String] = [:]

        let name = trimmed(form.name)
        if name.isEmpty {
            errors[.name] = "Enter your name."
        } else if name.count < nameLength.lowerBound {
            errors[.name] = "Name must be at least \(nameLength.lowerBound) characters."
        } else if name.count > nameLength.upperBound {
            errors[.name] = "Name can be at most \(nameLength.upperBound) characters."
        } else if name.rangeOfCharacter(from: .controlCharacters) != nil {
            errors[.name] = "Name contains invalid characters."
        }

        let email = trimmed(form.email)
        if email.isEmpty {
            errors[.email] = "Enter your email address."
        } else if email.count > emailMaxLength {
            errors[.email] = "Email address is too long."
        } else if email.range(of: #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#, options: .regularExpression) == nil {
            errors[.email] = "Enter a valid email address."
        }

        let phone = trimmed(form.phone)
        if !phone.isEmpty {
            if phone.range(of: #"^\+?[0-9 ()-]+$"#, options: .regularExpression) == nil {
                errors[.phone] = "Phone number can contain digits, spaces, +, -, ( and ) only."
            } else if !phoneDigits.contains(phone.filter(\.isASCIIDigit).count) {
                errors[.phone] = "Phone number must have \(phoneDigits.lowerBound)–\(phoneDigits.upperBound) digits."
            }
        }

        let message = trimmed(form.message)
        if message.count > messageMaxLength {
            errors[.message] = "Message can be at most \(messageMaxLength) characters."
        } else if message.rangeOfCharacter(from: disallowedMessageCharacters) != nil {
            errors[.message] = "Message contains invalid characters."
        }

        return errors
    }

    /// The request body: trimmed values, blank optional fields sent as "not provided" (omitted).
    static func request(from form: EnquiryForm, productID: String) -> EnquiryRequest {
        let phone = trimmed(form.phone)
        let message = trimmed(form.message)
        return EnquiryRequest(
            productId: productID,
            name: trimmed(form.name),
            email: trimmed(form.email),
            phone: phone.isEmpty ? nil : phone,
            message: message.isEmpty ? nil : message
        )
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Control characters except line breaks and tabs, which are fine in a message.
    private static var disallowedMessageCharacters: CharacterSet {
        CharacterSet.controlCharacters.subtracting(CharacterSet(charactersIn: "\n\r\t"))
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
