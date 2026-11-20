import XCTest
@testable import Kataloq

final class EnquiryFormValidatorTests: XCTestCase {
    private let valid = EnquiryForm(name: "Jane Citizen", email: "jane@example.com", phone: "", message: "")

    private func errors(_ change: (inout EnquiryForm) -> Void) -> [EnquiryField: String] {
        var form = valid
        change(&form)
        return EnquiryFormValidator.validate(form)
    }

    func testNameAndEmailAloneAreValid() {
        XCTAssertEqual(EnquiryFormValidator.validate(valid), [:])
    }

    func testAllFieldsFilledInAreValid() {
        XCTAssertEqual(errors { $0.phone = "+61 (0)400-000-000"; $0.message = "Is this in blue?\nThanks" }, [:])
    }

    func testRequiredFieldsAreReportedTogether() {
        XCTAssertEqual(EnquiryFormValidator.validate(EnquiryForm()), [
            .name: "Enter your name.",
            .email: "Enter your email address.",
        ])
    }

    func testWhitespaceOnlyCountsAsEmpty() {
        XCTAssertEqual(errors { $0.name = "   "; $0.email = "  " }[.name], "Enter your name.")
    }

    func testNameLength() {
        XCTAssertEqual(errors { $0.name = "J" }, [.name: "Name must be at least 2 characters."])
        XCTAssertEqual(errors { $0.name = String(repeating: "x", count: 101) }, [.name: "Name can be at most 100 characters."])
    }

    func testNameRejectsLineBreaks() {
        XCTAssertEqual(errors { $0.name = "Jane\nBcc: x@y.z" }, [.name: "Name contains invalid characters."])
    }

    func testInvalidEmails() {
        for email in ["jane", "jane@", "@example.com", "jane@example", "jane doe@example.com"] {
            XCTAssertEqual(errors { $0.email = email }, [.email: "Enter a valid email address."], email)
        }
    }

    func testPhoneRules() {
        XCTAssertEqual(errors { $0.phone = "0400 ABC" }, [.phone: "Phone number can contain digits, spaces, +, -, ( and ) only."])
        XCTAssertEqual(errors { $0.phone = "12345" }, [.phone: "Phone number must have 6–15 digits."])
        XCTAssertEqual(errors { $0.phone = "1234567890123456" }, [.phone: "Phone number must have 6–15 digits."])
        XCTAssertEqual(errors { $0.phone = "123456" }, [:])
    }

    func testMessageRules() {
        XCTAssertEqual(errors { $0.message = String(repeating: "x", count: 1001) }, [.message: "Message can be at most 1000 characters."])
        XCTAssertEqual(errors { $0.message = "Hi\u{0}there" }, [.message: "Message contains invalid characters."])
    }

    func testRequestTrimsAndOmitsBlankOptionalFields() {
        let form = EnquiryForm(name: " Jane ", email: " jane@example.com ", phone: "  ", message: "")

        let request = EnquiryFormValidator.request(from: form, productID: "1")

        XCTAssertEqual(request, EnquiryRequest(productId: "1", name: "Jane", email: "jane@example.com", phone: nil, message: nil))
    }
}

@MainActor
final class EnquiryViewModelTests: XCTestCase {
    private let product = Fixtures.product(id: "1", title: "Backpack")

    private func makeSUT(
        result: Result<EnquiryConfirmation, Error> = .success(EnquiryConfirmation(enquiryId: "e1", status: "sent"))
    ) -> (EnquiryViewModel, MockEnquiryRepository) {
        let repository = MockEnquiryRepository()
        repository.result = result
        let sut = EnquiryViewModel(product: product, repository: repository)
        trackForMemoryLeaks(sut)
        return (sut, repository)
    }

    private func fillValidForm(_ sut: EnquiryViewModel) {
        sut.update(.name, to: "Jane Citizen")
        sut.update(.email, to: "jane@example.com")
        sut.update(.phone, to: "")
        sut.update(.message, to: "Is this in blue?")
    }

    func testShowsTheProductBeingEnquiredAbout() {
        let (sut, _) = makeSUT()
        XCTAssertEqual(sut.productTitle, "Backpack")
        XCTAssertEqual(sut.state, .editing)
    }

    func testInvalidFormShowsFieldErrorsAndSendsNothing() async {
        let (sut, repository) = makeSUT()

        await sut.submit()

        XCTAssertEqual(sut.fieldErrors, [.name: "Enter your name.", .email: "Enter your email address."])
        XCTAssertEqual(sut.state, .editing)
        XCTAssertTrue(repository.submitted.isEmpty)
    }

    func testEditingAFieldClearsItsError() async {
        let (sut, _) = makeSUT()
        await sut.submit()

        sut.update(.name, to: "J")

        XCTAssertNil(sut.fieldErrors[.name])
        XCTAssertEqual(sut.fieldErrors[.email], "Enter your email address.")
    }

    func testSuccessfulSubmissionSendsTheRequestThenReportsSuccess() async {
        let (sut, repository) = makeSUT()
        fillValidForm(sut)
        var states: [EnquiryState] = []
        var submitted: (EnquiryConfirmation, String)?
        sut.onStateChange = { states.append($0) }
        sut.onSubmitted = { submitted = ($0, $1) }

        await sut.submit()

        XCTAssertEqual(repository.submitted, [
            EnquiryRequest(productId: "1", name: "Jane Citizen", email: "jane@example.com", phone: nil, message: "Is this in blue?"),
        ])
        let expected = EnquiryConfirmation(enquiryId: "e1", status: "sent")
        XCTAssertEqual(states, [.submitting, .submitted(expected)])
        XCTAssertEqual(submitted?.0, expected)
        XCTAssertEqual(submitted?.1, "jane@example.com")
    }

    func testFailureNeverReportsSuccessAndKeepsTheInput() async {
        let emailDown = APIError.server(
            status: 502, code: "EMAIL_DELIVERY_FAILED",
            message: "We could not send your enquiry right now. Please try again.", fieldErrors: []
        )
        let (sut, _) = makeSUT(result: .failure(emailDown))
        fillValidForm(sut)
        var didSubmit = false
        sut.onSubmitted = { _, _ in didSubmit = true }

        await sut.submit()

        XCTAssertFalse(didSubmit)
        XCTAssertEqual(sut.state, .failed(message: "We could not send your enquiry right now. Please try again."))
        XCTAssertEqual(sut.form.name, "Jane Citizen")
        XCTAssertEqual(sut.form.email, "jane@example.com")
    }

    func testRetryAfterFailureSucceeds() async {
        let (sut, repository) = makeSUT(result: .failure(APIError.transport(.cannotConnectToHost)))
        fillValidForm(sut)
        await sut.submit()
        XCTAssertEqual(sut.state, .failed(message: "Can't reach Kataloq right now. Please try again."))

        repository.result = .success(EnquiryConfirmation(enquiryId: "e2", status: "sent"))
        await sut.submit()

        XCTAssertEqual(sut.state, .submitted(EnquiryConfirmation(enquiryId: "e2", status: "sent")))
        XCTAssertEqual(repository.submitted.count, 2)
    }

    func testServerFieldErrorsAreShownInline() async {
        let validation = APIError.server(
            status: 400, code: "VALIDATION_ERROR", message: "Some fields are invalid.",
            fieldErrors: [FieldError(field: "email", message: "Email address is too long.")]
        )
        let (sut, _) = makeSUT(result: .failure(validation))
        fillValidForm(sut)

        await sut.submit()

        XCTAssertEqual(sut.fieldErrors, [.email: "Email address is too long."])
        XCTAssertEqual(sut.state, .editing)
    }

    func testCannotSubmitAgainAfterSuccess() async {
        let (sut, repository) = makeSUT()
        fillValidForm(sut)

        await sut.submit()
        await sut.submit()

        XCTAssertEqual(repository.submitted.count, 1, "Each submission sends an email, so it must only happen once")
    }

    func testCancelForwardsTheIntent() {
        let (sut, _) = makeSUT()
        var cancelled = false
        sut.onCancel = { cancelled = true }

        sut.cancel()

        XCTAssertTrue(cancelled)
    }

    func testThankYouShortReferenceIsTheFirstBlockOfTheEnquiryID() {
        let content = ThankYouContent(
            productTitle: "Backpack", replyEmail: "jane@example.com", enquiryID: "ecaec87e-221f-415d-991a-dbf22b48317d"
        )
        XCTAssertEqual(content.shortReference, "ECAEC87E")
        XCTAssertEqual(ThankYouContent(productTitle: "", replyEmail: "", enquiryID: "e1").shortReference, "E1")
    }
}
