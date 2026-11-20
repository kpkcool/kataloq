# AGENTS.md – Instructions for AI coding agents working on Kataloq

Read this before changing anything. Then read `docs/ARCHITECTURE.md` (design and API contract) and `DECISIONS.md` (why things are the way they are). Do not silently change an approved decision; propose it and explain the trade-off.

## Project

**Kataloq – Product Catalogue Platform.** Native iOS app + REST backend.

| Thing | Name |
|---|---|
| iOS app / Xcode project / main target | `Kataloq` (`ios/Kataloq.xcodeproj`), tests in `KataloqTests` |
| Backend service | `kataloq-api` (`backend/`) |
| Repository | `kataloq` |

```
ios/Kataloq/        App/ Coordinators/ Core/{Networking,ImageLoading,Formatting}/ Models/
                    Repositories/ Features/{Home,Category,Search,ProductDetail,Enquiry,Shared}/ UIComponents/
backend/src/        config/ routes/ controllers/ http/ middleware/ services/ domain/
                    providers/{product,email}/  app.ts container.ts server.ts
docs/               REQUIREMENTS, ARCHITECTURE, TESTING, CODE_REVIEW, SUBMISSION
```

## Non-negotiable architecture rules

1. **The iOS app never calls Fake Store API (or any product data source) directly.** It only calls `kataloq-api`. It may load image bytes from the `imageUrl` the backend returns.
2. **Business rules live in the backend** (`backend/src/domain`, `backend/src/services`): featured selection, category ranking and the top-N split, search matching, enquiry validation. The app must not re-sort or re-filter what the backend returns.
3. **Services depend on interfaces, not vendors.** Product data goes through `ProductProvider`, email through `EmailProvider`. Concrete adapters are chosen only in `backend/src/container.ts`. Fake Store response shapes never leave `providers/product/`.
4. **Our API contract is the domain model** (`backend/src/domain/types.ts`): camelCase, string IDs, `price {amount, currency}`, `rating {average, count}`, category `{id: slug, name}`. Change it only together with the iOS models and tests.
5. **MVVM-C on iOS.** ViewModels: `@MainActor`, Foundation only (never `import UIKit`), expose state plus intent closures. ViewControllers render state and forward input; no networking, no navigation decisions. `AppCoordinator` does all navigation and dependency wiring. Dependencies are passed by initializer through `AppDependencies`. No DI framework.
6. **Only abstract real seams.** Protocols exist for things that are swapped or mocked (`ProductProvider`, `EmailProvider`, `APIClient`, repositories, `ImageLoading`). Don't add protocols, base classes or generic layers "for the future".

## Technology constraints

- **iOS:** Swift (Swift 5 language mode), UIKit only (**no SwiftUI**), programmatic layout (no storyboards except the launch screen), compositional layout + diffable data sources, URLSession + async/await, Codable, XCTest. Deployment target **iOS 16.0**, iPhone, portrait. **No third-party dependencies.**
- **Backend:** Node.js 24+ (Docker uses `node:26-alpine`), TypeScript strict (`noUncheckedIndexedAccess` on), ESM (`.js` extensions in imports), Express 5, zod for every external input (env, params, query, body, upstream JSON), nodemailer, express-rate-limit, vitest + supertest. Use native `fetch`; don't add axios, DI containers or logging libraries.
- **No paid services or accounts** may be required to run or review the project. Email goes to Mailpit locally.

## Code standards

**Swift**
- No force unwraps, `try!` or `as!` in app code. Use `guard`, and `preconditionFailure` only for programmer errors in literals.
- Every closure stored by a ViewModel, view or coordinator captures `[weak self]`. Long-running `Task`s capture the ViewModel, not the ViewController, and are cancelled in `deinit`.
- `CancellationError` is never shown to the user.
- Styling only through `Theme`, and reuse `ProductCardCell`, `StateView`, `LayoutSections`, `FormFieldView`.
- Every screen handles loading, empty, failure (with retry) and success.
- Accessibility: Dynamic Type fonts (`adjustsFontForContentSizeCategory`), VoiceOver labels for tiles, buttons and images.
- Name the category model `ProductCategory` (not `Category`, which clashes with an Objective-C runtime type).

**TypeScript**
- Throw the typed errors in `domain/errors.ts`. Only `middleware/errorHandler.ts` turns errors into HTTP responses.
- Error messages in `AppError`s are shown to customers: keep them safe and free of internals.
- **Never log request bodies, query strings or personal data** (names, emails, phones, messages). Log IDs only.
- Configuration only through `config/env.ts` (validated, with defaults). Document every new variable in `backend/.env.example`.

## Testing requirements

- Every behaviour change comes with tests: backend in `backend/tests/{unit,integration}`, iOS in `ios/KataloqTests`.
- Unit tests never touch the network or Docker. Use `InMemoryProductProvider`, `FakeEmailProvider`, injected `fetch` and clocks, and on iOS the `Mock*` types and `URLProtocolStub`.
- New ViewModels and coordinator-built screens get `trackForMemoryLeaks`.
- Test both success and failure paths. For enquiries, always assert that a provider failure is **never** reported as success.
- Before saying anything passes, **run it**:
  - `cd backend && npm run typecheck && npm test && npm run build`
  - `xcodebuild test -project ios/Kataloq.xcodeproj -scheme Kataloq -destination 'platform=iOS Simulator,name=<device>'`
  - `./scripts/verify.sh` for the full run including the end-to-end smoke test.

## Prohibited shortcuts

- Claiming tests pass, or that something was run, without output from an actual run. Report unverified work as unverified.
- Calling Fake Store (or any product data source) from the app; adding a client-side fallback to Fake Store.
- Bypassing, spoofing or solving Fake Store's Cloudflare bot protection. Surface it as `UPSTREAM_UNAVAILABLE` instead.
- Reporting an enquiry as sent unless the email provider accepted it. Automatically retrying `POST /enquiries`.
- Committing secrets, `.env` files, `node_modules`, `dist`, or `xcuserdata`.
- Disabling TypeScript strictness, swallowing errors silently, or using `any` to get past the compiler.
- Turning App Transport Security off globally (only `NSAllowsLocalNetworking` is allowed).

## Git and documentation

- Work on a feature branch with small, meaningful commits. Don't force-push or rewrite shared history. The pull request into `main` stays **open** for review.
- Update docs in the same change: `DECISIONS.md` for any new decision or deviation (with the reason), `backend/README.md` and `.env.example` for API or config changes, `docs/TESTING.md` for new results (actual output only), and `README.md` if setup changes.
