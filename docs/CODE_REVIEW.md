# Kataloq – Code Review (Phase 6)

**Scope:** `backend/` (kataloq-api) and `ios/` (Kataloq app) on `feature/kataloq-mvp`, after Phase 4.
**Method:** file-by-file read of all source and tests against the review checklist below, plus automated scans for force unwraps / `try!` / `as!`, strong `self` captures, TODOs, `console.*`, secret-like strings and wrongly tracked files.

**Limitation, stated honestly:** this review was done by the same AI assistant that wrote the code, without an independent reviewer and without a Swift compiler (iOS code is compiled and tested only on the developer's Mac). Treat it as a structured self-review, not an external audit. Findings marked *Accepted* are deliberate and documented in `DECISIONS.md`.

## Summary

| Severity | Found | Fixed | Accepted / documented |
|---|---|---|---|
| Critical | 0 | – | – |
| High | 0 | – | – |
| Medium | 3 | 1 | 2 |
| Low | 8 | 1 | 7 |

Automated scans: no force unwraps, `try!` or `as!` in app code; no strong `self` captures in closures; no TODO/FIXME; no secrets; no `node_modules`, `dist`, `.env` or `xcuserdata` tracked. One `console.error` in `server.ts` is intentional (it reports invalid configuration before the logger exists).

## Findings

| # | Area | File / location | Problem | Why it matters | Severity | Resolution |
|---|---|---|---|---|---|---|
| R1 | iOS stability | `HomeViewModel`, `CategoryViewModel`, `SearchViewModel` → diffable data sources | `UICollectionViewDiffableDataSource` traps (crashes) if a snapshot contains the same item twice. The app trusted the backend never to send duplicates. | A malformed or changed backend response would crash the app instead of degrading. | Medium | **Fixed.** `Array<Product>.uniquedByID()` keeps first occurrence and order; Category also drops "All Products" items already in "Top Rated". Test: `testDuplicateProductsInAMalformedResponseAreDroppedInsteadOfCrashing`. |
| R2 | Testing | `ios/Kataloq/Features/**/…ViewController.swift`, `FormFieldView` | ViewControllers and views have no automated tests (no UI or snapshot tests; UI test target removed by decision D12). | Rendering bugs are only caught manually, e.g. the grid overflow found from a screenshot in Phase 4. | Medium | **Accepted.** Logic lives in ViewModels (fully tested); coordinator navigation tested. Snapshot tests listed as a "next day" item. |
| R3 | Abuse protection | `backend/src/middleware/rateLimiter.ts` | Rate limit is in memory and keyed by client IP. Behind Docker's port mapping all clients share one IP; with several instances each has its own counter. | Locally the 5/min limit is effectively global; in production it needs a shared store or edge throttling. | Medium | **Accepted / documented** (DECISIONS §6). Fine for a single-instance PoC. |
| R4 | Logging noise | `backend/src/middleware/requestContext.ts` | Compose health checks every 10 s were each logged at `info`. | Real request logs get buried; log costs on CloudWatch. | Low | **Fixed.** `/health` is logged at `debug`. Test added. |
| R5 | Performance | `backend/src/app.ts` | JSON body parsing runs before the enquiry rate limiter. | A flood of 10 KB bodies is parsed before being rejected. Bounded by the 10 KB limit. | Low | **Accepted.** Move the limiter before parsing (or to the edge) at scale. |
| R6 | Performance | `ios/Kataloq/Core/ImageLoading/ImageLoader.swift` | Concurrent requests for the same image URL aren't de-duplicated (only completed images are cached). | Possible duplicate downloads while scrolling quickly. | Low | **Fixed (2026-11-20, design-system round).** `URLSessionImageLoader` now shares one in-flight download per URL; covered by `URLSessionImageLoaderTests`. Disk cache remains a "next day" item. |
| R7 | Resilience | `backend/src/services/EnquiryService.ts` | Enquiries aren't persisted; if the email provider is down the enquiry is lost unless the user retries. | Lost leads during an email outage. | Low | **Accepted** (AS, "simplified"). The user is always told it failed (never a false "Thank you"). Outbox + retries is next-day item 1. |
| R8 | Idempotency | `POST /api/v1/enquiries`, `EnquiryViewModel.submit` | No idempotency key. A response lost in transit, followed by a user retry, sends a second email. | Duplicate leads in rare network failures. | Low | **Accepted.** Client prevents double-tap (state machine) and never auto-retries. Idempotency key listed as next step. |
| R9 | Config | `ios/Kataloq/App/AppConfiguration.swift` | Default base URL is `http://localhost:3000`, which only works on the Simulator. | A physical device needs `KATALOQ_API_BASE_URL` set to the Mac's LAN address. | Low | **Accepted / documented** in README. |
| R10 | Duplication | `HomeViewController`, `CategoryViewController`, `SearchViewController` | Similar render / snapshot / registration code in three controllers. | Some repetition when changing shared behaviour. | Low | **Accepted.** A base class or generic list controller would add abstraction for 3 screens; shared pieces (`LayoutSections`, `ProductCardCell`, `StateView`) are already extracted. Revisit if a 4th list screen appears. |
| R11 | Concurrency | iOS mocks (`@unchecked Sendable`), `URLProtocolStub` (`nonisolated(unsafe)` statics) | Test doubles opt out of Sendable checking. | Safe only because XCTest runs these tests serially. | Low | **Accepted.** Test-only code; production types are genuinely `Sendable` or `@MainActor`. |

## Checklist results

### Architecture and separation of concerns
- iOS never calls Fake Store for product data; only `RemoteProductRepository` knows endpoint paths. Images load from backend-supplied URLs (AD-15).
- Backend: services depend only on `ProductProvider` / `EmailProvider`; `container.ts` is the only place choosing adapters; Fake Store types never leave the adapter.
- Business rules (featured, ranking, search) live in backend domain functions; iOS doesn't re-sort.

### MVVM-C
- ViewModels import Foundation only, own state and intents, and are `@MainActor`. ViewControllers render state and forward input. All navigation goes through `AppCoordinator`. **OK.**

### Memory management
- Every ViewModel → ViewController / coordinator closure captures `[weak self]`. Cell image tasks and screen load tasks are cancelled on reuse / `deinit`; load tasks capture the ViewModel, not the controller, so screens can deallocate mid-request.
- Leak tests (`trackForMemoryLeaks`) cover all ViewModels, the coordinator and every screen it builds. **OK** (pending the test run).

### Concurrency and main thread
- UI types and ViewModels are `@MainActor`; networking types are `Sendable` and not main-actor bound. Cancelled requests surface as `CancellationError` and never show an error state. Search cancels the previous search before starting a new one. **OK.**

### Networking and error handling
- Status validation, backend error-body decoding, URLError mapping (offline / can't connect / timeout / cancelled), 15 s request timeout, correct query encoding of `+` and `&`. **OK.**
- Backend: typed errors, one error handler, no stack traces or upstream details in responses, 5 s upstream timeout, Cloudflare challenge surfaced (not bypassed). **OK.**

### Security
- Input validated on every endpoint (zod); 10 KB body limit; header-injection guards on name/email/phone; plain-text email; no PII in logs (tested); no secrets committed; ATS on except localhost; non-root Docker user. **OK** with R3 / R5 noted.

### Unnecessary abstraction / dead code
- No unused dependencies (each backend package is imported). No dead code found. Protocols exist only at seams that are replaced or mocked (`ProductProvider`, `EmailProvider`, `APIClient`, repositories, `ImageLoading`).

## Verification of the fixes

| Fix | Test | Result |
|---|---|---|
| R1 duplicate guard | `CategoryViewModelTests.testDuplicateProductsInAMalformedResponseAreDroppedInsteadOfCrashing` | **Not yet run** — see `docs/TESTING.md` |
| R4 health log level | `catalogue.api.test.ts` › "logs health checks at debug level only" | **Not yet run** — see `docs/TESTING.md` |
