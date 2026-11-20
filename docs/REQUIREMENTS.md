# Kataloq – Product Catalogue Platform
## Phase 1: Requirements Analysis

Status: **Approved with amendments.** Ambiguities A1–A18 below are the original Phase 1 proposals. Where they differ from what was finally approved (notably A2: category "top rated" is computed by rating, not curated), `docs/ARCHITECTURE.md` §0 (decisions D1–D15) and `DECISIONS.md` take precedence. · Source: *Code Challenge: AI-Native Engineer* (4 pages) · Date: 2026-11-19

Nothing in this document has been implemented yet. Statements marked **[Assumption]** are not in the assignment. They are proposals for you to approve or change.

---

## 1. Business objective

An entrepreneur needs an interactive proof of concept of a product catalogue, so they can start shaping the product while design work runs in parallel. Customers browse and search products and submit an enquiry about a product.

The key business constraint is that **the PoC must not be thrown away**. The assignment names three things that are expected to change:

| Expected to change | What that means for design |
|---|---|
| Product data source (Fake Store API today) | Backend hides it behind a product-provider interface; the client never sees it |
| Look and feel (creative work in progress) | iOS styling centralised (theme/reusable components), not scattered through screens |
| Email provider | Backend hides it behind an email-provider interface |

The reviewers assess **judgement, not feature count**: a small, well-reasoned solution beats a large unexplained one.

---

## 2. Functional requirements (summary)

| ID | Capability | Source |
|---|---|---|
| FR-1 | Home page shows the 5 chosen "top rated" (featured) products | AC: Home page |
| FR-2 | Category navigation: list categories and open a category | AC: Category page (implied "category link") |
| FR-3 | Category page shows that category's top rated products, then the additional products | AC: Category page |
| FR-4 | Search by text, triggered by a search button, showing only matching products | AC: Search |
| FR-5 | Tapping a product tile opens the product details page | AC: Product page |
| FR-6 | Enquire button on details opens a contact form | AC: Enquiry |
| FR-7 | Submitting the form sends an email to the sales inbox | AC: Enquiry |
| FR-8 | After successful submission the customer sees a "Thank you" message | AC: Enquiry |

---

## 3. Non-functional requirements

| ID | Requirement | Source |
|---|---|---|
| NFR-1 | Clear boundaries between client, backend and product data source | Selection criteria: Solution design |
| NFR-2 | Product data source and email provider replaceable without touching business logic or the client | Scenario |
| NFR-3 | Readable, consistent code; sensible error handling, input validation, security basics | Selection criteria: Implementation quality |
| NFR-4 | Tests cover the critical path and give confidence to change code | Selection criteria: Testing |
| NFR-5 | Reviewer can run everything locally in under 10 minutes from the README | Constraint 4 |
| NFR-6 | No secrets committed; configuration via `.env.example` | Constraint 5 |
| NFR-7 | No paid services or accounts needed by the reviewer | Constraint 6 |
| NFR-8 | Any infrastructure must be AWS-compatible | Constraint 3 |
| NFR-9 | Loading, empty, success and failure states handled on every screen | Project working agreement |
| NFR-10 | Basic accessibility (VoiceOver labels, Dynamic Type where cheap) | Project working agreement **[Assumption: scope]** |

---

## 4. iOS application requirements

- Swift, **UIKit only**, programmatic UI, **MVVM-C**, URLSession + async/await, Codable, protocol-based DI, XCTest. No third-party dependencies.
- Screens: Home (featured + category links + search entry), Category, Search, Product Details, Enquiry form, Thank-you state.
- Product tile shows image, title, price and rating.
- Talks **only** to `kataloq-api`. Base URL configurable (Simulator: `http://localhost:<port>`).
- Must build and run on the iOS Simulator against the locally running backend.
- Image loading must tolerate missing or failed images (placeholder).

**Current repo state (checked):** a fresh Xcode project at the repo root (`Kataloq.xcodeproj`, `Kataloq/`, `KataloqTests/`, `KataloqUITests/`), one "Initial Commit" on `main`, no remote. It still uses `Main.storyboard` (`UISceneStoryboardFile = Main`), which we'll remove for programmatic UI. The project uses Xcode's folder-based project format, so new Swift files in `Kataloq/` are picked up automatically.

## 5. Backend requirements

- Node.js + TypeScript (strict), REST, service name `kataloq-api`.
- Layers: routes → controllers → services → provider interfaces → adapters (Fake Store, email).
- Owns all business rules: featured selection, category grouping (top rated first, no duplicates), search matching, enquiry validation, email composition.
- Maps Fake Store responses into Kataloq's own domain models; Fake Store shapes never reach the client.
- Environment-driven config; centralised error handling; upstream timeouts; safe error responses (no stack traces or secrets).
- Unit tests (mocked providers) + integration tests (HTTP layer with fake providers).

## 6. External API requirements (Fake Store API)

- Source of product data, accessed **only** from the backend (Constraint 2).
- Relevant endpoints: `GET /products`, `GET /products/{id}`, `GET /products/categories`, `GET /products/category/{name}`. The catalogue is small (~20 products, 4 categories: electronics, jewelery, men's clothing, women's clothing). *To verify against the live API at the start of Phase 3.*
- Fake Store has **no search endpoint and no "featured" concept**, so search and featured selection are backend logic, not an upstream capability. That's good: it keeps these rules in our code, independent of the data source.
- It is a free public service that can be slow or down. The backend needs timeouts and clean `502/504`-style errors. **[Assumption]** A short-TTL in-memory cache is worth considering (decided in Phase 2).

## 7. Enquiry and email requirements

- Entry: Enquire button on a product's details page.
- Form collects "contact details" (fields not specified — see A6).
- On submit: backend validates, composes an email that includes the product, and sends it to the **sales inbox** through the email provider.
- "Thank you" is shown **only** after the backend confirms the email provider accepted the message. A failure must not be reported as success.
- Reviewer must be able to **see the email locally for free** (Constraint 6). Candidate approach for Phase 2: an SMTP adapter pointed at a local mail catcher (e.g. Mailpit), so the reviewer opens a web inbox to see the email.

## 8. Technical constraints

1. One client + one backend → **iOS (Swift, UIKit) + Node.js (TypeScript)**. Choice and reasons go in the README.
2. No Fake Store calls from the client.
3. Infrastructure, if any, AWS-compatible.
4. Local run in < 10 minutes; app runs on the iOS Simulator against the local backend.
5. No committed secrets; `.env.example` provided.
6. No paid services or reviewer accounts.
7. Time-box 2–3 hours; actual time reported honestly (going over is fine if stated).

## 9. Submission requirements

| # | Item | Planned file / action |
|---|---|---|
| S-1 | Git repo (GitHub/GitLab/Bitbucket; reviewers get access if private) | GitHub repo `kataloq` |
| S-2 | Feature branch + **open** PR into `main`; PR description is assessed | `feature/...` branch, PR left open |
| S-3 | Full source including tests | iOS + backend |
| S-4 | README with setup/run/config | `README.md` |
| S-5 | Decisions & assumptions: assumptions, dropped/simplified requirements, how the design grows, next day's work | `DECISIONS.md` |
| S-6 | AI usage: tools and models, agent instruction files committed, plan/spec, 3–5 key prompts, where AI got it wrong and how it was caught | `AI_USAGE.md`, `AGENTS.md`, this document as the spec |
| S-7 | Time spent, split across planning / building / testing / reviewing | Section in `AI_USAGE.md` or README |
| S-8 | Deadline: within 3 days of receiving the email | — |

## 10. Evaluation criteria

| Area | What they look for | How Kataloq addresses it |
|---|---|---|
| Solution design | Structure that grows beyond the PoC; clear frontend/backend/data-source boundaries | Provider interfaces, domain models, client only talks to own API |
| Decision-making & assumptions | Sensible assumptions, clear trade-offs, justified cuts | Section 13 of this doc → `DECISIONS.md` |
| Implementation quality | Readable, consistent code; error handling, validation, security basics | Validation both sides, central error handler, no secrets, safe errors |
| Testing | Critical-path tests that give confidence to change | Backend unit + integration; iOS ViewModel/repository/decoding tests |
| AI engineering practice | Effective direction of AI, critical review, ownership | Staged approval workflow, honest `AI_USAGE.md` |

There's also a **45-minute follow-up** where you walk through the code and **make a small change live**. That argues for simple, conventional code you can change quickly over clever abstractions.

---

## 11. Detailed functional requirements

### FR-1 — Home: featured products
- **User story:** As a customer, I want to see a curated set of featured products when I open the app, so I can quickly discover recommended items.
- **Acceptance criteria:**
  - Given 5 products are configured as featured, the home screen shows exactly those 5, in configured order.
  - Each tile shows image, title, price and rating.
  - Loading, error (with retry) states are shown.
- **Expected behaviour:** App launch → loading indicator → 5 tiles. Backend down → error message + Retry.
- **Backend:** `GET /featured` (path decided in Phase 2) resolves the configured IDs via the product provider; config validated at startup (exactly 5 unique positive integers).
- **iOS:** `HomeViewModel` loads featured products and exposes state; `HomeViewController` renders; coordinator handles tile tap.
- **Tests:** backend returns 5 products in configured order; invalid config rejected at startup; upstream failure → 502; iOS ViewModel transitions loading → loaded / loading → failed; retry reloads.

### FR-2 — Category navigation
- **User story:** As a customer, I want to see the product categories and pick one, so I can browse a section of the catalogue.
- **Acceptance criteria:** Categories come from the backend; tapping one opens its category page.
- **Expected behaviour:** Category links are visible from Home; tap → Category screen.
- **Backend:** `GET /categories` from the provider, mapped to `{ id/slug, name }`.
- **iOS:** Categories shown on Home (e.g. horizontal chips or a section); coordinator pushes Category screen.
- **Tests:** backend maps categories; upstream failure → 502; iOS shows categories and routes the tap.

### FR-3 — Category page: top rated then additional
- **User story:** As a customer, I want to see a category's top rated products first and then the rest of that category, so I see the best options first without missing anything.
- **Acceptance criteria:**
  - Shows the category's top rated products in their own section first.
  - Shows the category's remaining products in a second section.
  - No product appears in both sections.
  - Only products from that category appear.
  - Unknown category → not-found state.
- **Expected behaviour:** Two sections, "Top rated" and "More in <category>"; a section with no items is hidden.
- **Backend:** returns `{ category, topRated: [...], additional: [...] }`. The partitioning rule lives on the backend so all clients agree.
- **iOS:** `CategoryViewModel` exposes sections; collection view with section headers.
- **Tests:** partition correctness, no duplicates, category filtering, empty top-rated section, unknown category → 404, case/encoding of category names (e.g. `men's clothing`).

### FR-4 — Search
- **User story:** As a customer looking for a specific product, I want to enter a term and tap Search, so I only see products matching that term.
- **Acceptance criteria:**
  - Search runs when the search button is tapped (keyboard Search key counts).
  - Results contain **only** products whose text matches the term.
  - Empty/whitespace term is not sent; the user is prompted.
  - No matches → empty state ("No products match '…'").
  - Errors → error state with retry.
- **Backend:** `GET /products/search?q=` (path decided in Phase 2). Trim, case-insensitive substring match on title, description and category. Empty `q` → 400. Max length enforced.
- **iOS:** `SearchViewModel` validates the term, calls the repository, exposes idle/loading/results/empty/error; cancels an in-flight search when a new one starts.
- **Tests:** case-insensitivity, matches in each field, non-matching products excluded, empty term → 400, overlong term → 400, special characters don't break matching; iOS empty-term guard, empty/results/error states, cancellation.

### FR-5 — Product details
- **User story:** As a customer, I want to tap a product tile and see its full details, so I can decide whether to enquire.
- **Acceptance criteria:** Tapping any product tile (Home, Category, Search) opens details showing image, title, description, price, category, rating and an Enquire button. Unknown ID → not-found state.
- **Backend:** `GET /products/:id`; non-numeric ID → 400; missing → 404.
- **iOS:** coordinator receives the tap from any list; `ProductDetailViewModel` fetches by ID (see A5 for why fetch rather than pass through).
- **Tests:** mapping, 400/404, upstream failure; iOS loads and renders state; navigation from each list.

### FR-6 / FR-7 / FR-8 — Enquiry, email, thank-you
- **User story:** As an interested customer, I want to send my contact details about a product, so the sales team can follow up; and I want confirmation it was sent.
- **Acceptance criteria:**
  - Enquire button on details opens a form for that product.
  - Form validates fields client-side before submission (inline errors).
  - Submit shows a loading state and prevents double submission.
  - On success the sales inbox receives an email identifying the customer and the product, and the customer sees "Thank you".
  - On failure the customer sees a useful error, entered data is kept, and they can retry.
- **Backend:** `POST /enquiries`. Validates fields (server is the source of truth), checks the product exists, composes the email, sends via `EmailProvider` to `SALES_INBOX_EMAIL`. `201/202` only if the provider accepted the message; provider failure → `502`; validation → `400` with field errors; body size limited.
- **iOS:** `EnquiryViewModel` handles validation and submit state; coordinator shows the thank-you state on success.
- **Tests:** each validation rule (backend and iOS), unknown product, provider success, **provider failure never reports success**, email content contains product and contact details, header injection rejected (newlines in name/email), iOS success → thank-you navigation, failure → retryable error.

---

## 12. Traceability matrix

Planned components and tests. Names are provisional until Phase 2 approval.

| Req | Backend implementation | iOS implementation | Backend tests | iOS tests |
|---|---|---|---|---|
| FR-1 | `CatalogueService.getFeatured`, featured config | `HomeViewModel`, `HomeViewController` | service unit; `GET /featured` integration; config validation | `HomeViewModelTests` |
| FR-2 | `CatalogueService.getCategories` | Home categories section, `AppCoordinator` | service unit; `GET /categories` integration | `HomeViewModelTests` (categories), coordinator test |
| FR-3 | `CatalogueService.getCategoryPage` (partition) | `CategoryViewModel`, `CategoryViewController` | partition / no-dup / 404 unit + integration | `CategoryViewModelTests` |
| FR-4 | `SearchService` / matcher | `SearchViewModel`, `SearchViewController` | matcher unit; `GET /products/search` integration | `SearchViewModelTests` |
| FR-5 | `CatalogueService.getProduct` | `ProductDetailViewModel`, `ProductDetailViewController` | 400/404/200 integration | `ProductDetailViewModelTests` |
| FR-6 | — | `EnquiryViewController`, coordinator route | — | coordinator test |
| FR-7 | `EnquiryService`, validator, `EmailProvider` + SMTP adapter | `EnquiryViewModel` submit | validator unit; provider success/failure; `POST /enquiries` integration | `EnquiryViewModelTests` |
| FR-8 | success status only on provider acceptance | Thank-you state | provider-failure test | `EnquiryViewModelTests` (success/failure) |
| NFR-1/2 | `ProductProvider`, `EmailProvider` interfaces; domain mappers | `ProductRepository` protocol, `APIClient` | `FakeStoreProductProvider` mapping tests with mocked HTTP | repository tests with mocked `APIClient` |
| NFR-3 | central error middleware, validation, timeouts | typed `APIError`, no force unwraps | error-handler tests, upstream timeout | networking/decoding tests |
| NFR-5/6/7 | `.env.example`, local mail catcher | configurable base URL | — | — (verified manually in Phase 5) |
| NFR-9 | — | shared state views | — | ViewModel state tests per screen |

---

## 13. Ambiguities and proposed assumptions

| # | What's missing | Proposed assumption | Why it's reasonable | Impact |
|---|---|---|---|---|
| A1 | **Who chooses the 5 "top rated" products, and how?** "I have chosen" implies a human curation, not a computed rating. | The owner configures 5 product IDs in backend config (env var, e.g. `FEATURED_PRODUCT_IDS=1,5,9,14,18`), with defaults in `.env.example`. Startup fails fast if it isn't exactly 5 unique IDs. Displayed in configured order. | Matches "I have chosen"; no admin UI or database needed for a PoC; trivially replaced by a CMS/DB later behind the same service method. | Featured selection lives in the backend service, not in the provider. |
| A2 | **"Top rated products for that category"** — the same curated set, or another per-category choice, or Fake Store's `rating.rate`? | "Top rated" means the same curated featured set. A category's top rated section = featured products in that category; additional = all other products in that category. Choose the default 5 IDs so they span all 4 categories. If a category has no featured products, the section is hidden. | Uses one consistent definition of "top rated" across both criteria instead of inventing a second rule. | Category endpoint returns two lists; partition logic in the backend. **Alternative** (if you prefer): rank by `rating.rate` per category. Please confirm. |
| A3 | Where are category links? | Category list shown on Home; categories come from the data source, not hardcoded. | "When I click on a category link" needs an entry point; Home is the natural one. | Extra `GET /categories` endpoint. |
| A4 | **Search matching rules** — fields, case, partial words, multiple words, empty term. | Trimmed, case-insensitive substring match of the whole phrase against title, description and category. Empty → not sent (client) / 400 (server). Max 100 chars. Search runs on button tap (and keyboard Search), not as-you-type. *Updated 2026-11-20 (engineer's decision): the search bar is on Home and also searches as the user types, after a 300 ms pause; the Search button still triggers a search immediately. See DECISIONS.md.* | Simplest rule that satisfies "text matching"; predictable and easy to test. Matching description gives broader results; this is a stated trade-off. | Search implemented in the backend over the full product list (Fake Store has no search). Doesn't scale to a large catalogue → note in DECISIONS.md (future: search index / provider-side search). |
| A5 | Does the details page show already-loaded data or refetch? | Navigate with the product ID; details screen fetches `GET /products/:id`. | Details screen works from any entry point (and future deep links); data source can return richer detail later. | One extra request per details view. Slight latency trade-off. |
| A6 | **Which contact fields?** | Name (required, 2–100 chars), email (required, valid format), phone (optional, loose format), message (optional, ≤1000 chars). Product ID sent automatically. | "Contact details" minimally means a name and a way to reply; phone and message are useful to sales but shouldn't block a lead. | Validation rules shared in intent between iOS (UX) and backend (authority). |
| A7 | **Where is the sales inbox and how does the reviewer see the email for free?** | `SALES_INBOX_EMAIL` env var (e.g. `sales@kataloq.local`). SMTP adapter pointed at a free local mail catcher (Mailpit) so the reviewer opens a local web inbox. Exact setup decided in Phase 2. | Real email path end to end, no paid account; swapping to SES/SendGrid later means a new adapter + env vars. | Needs Docker or a local Mailpit binary for the reviewer — must fit the 10-minute setup. |
| A8 | What counts as "the sales inbox will receive an email"? | Success = the email provider accepted the message (SMTP accepted / API 2xx). Thank-you shown only then. | We can't observe inbox delivery synchronously; acceptance is the industry-standard success signal. | Provider failure → 502 and retryable error in the app. |
| A9 | Are enquiries stored? | No persistence; email is the only record. | Not required; avoids a database in the PoC. | Lost if the email fails — the user is told and can retry. Noted as a "next day" item (store + outbox/retry). |
| A10 | Abuse protection for the enquiry endpoint? | Body size limit, input validation, CRLF/header-injection protection, and a simple in-memory per-IP rate limit. | "Security basics" is assessed; a public form that sends email is an obvious spam vector. | Small amount of middleware. In-memory limit doesn't work across instances → noted. |
| A11 | Prices: currency? | Fake Store prices treated as dollar amounts, shown with 2 decimals and a `$` sign via a single formatter. | Data is placeholder; one formatter makes changing currency trivial. | None. |
| A12 | A configured featured ID no longer exists upstream? | Startup validates format only; at runtime missing products are skipped and logged, so the home page degrades instead of failing. | Data source is outside our control; partial content beats an error page. | Home may show fewer than 5 → logged warning. Please confirm (alternative: fail the request). |
| A13 | Upstream slow/unavailable? | 5-second upstream timeout; upstream errors → `502`, timeout → `504`, consistent JSON error body. Short-TTL in-memory cache optional (Phase 2 decision). | Fake Store is a free public API with variable latency. | Error mapping in the provider adapter + error middleware. |
| A14 | Auth, accounts, cart, pagination, sorting, offline? | None. | Not in acceptance criteria; the catalogue has ~20 products. | Documented as out of scope. |
| A15 | iOS deployment target / devices? | iPhone, portrait, iOS 16+ (iPad not optimised). | Covers async/await and modern UIKit list APIs; no reason to support older. | Please confirm target in Xcode project. |
| A16 | AWS infrastructure? | No infrastructure as code. Optionally a backend `Dockerfile` (runs on ECS/App Runner). | Constraint only applies "if you include infrastructure"; time-box. | None for the PoC. |
| A17 | "Look and feel will change" — how much theming? | Central colours/fonts/spacing constants and reusable tile/state views; no design system. | Makes a reskin a small change without overbuilding. | Small `Theme` file on iOS. |
| A18 | Repo layout: the Xcode project currently sits at the repo root; where does the backend go? | Monorepo: `ios/` (Xcode project moved here) and `backend/` (`kataloq-api`), docs at root. | One repo, one PR, one README is what the submission asks for. | Requires moving the existing Xcode files in Phase 2/3 (needs your OK). |

---

## 14. Risks and constraints to flag now

1. **I can't build or run the iOS app from this environment.** The shell that reaches your `Kataloq` folder is a Linux VM: Node.js 22 is available (backend can be built and tested here), but there's **no Xcode/`xcodebuild`**. For iOS, I'll write the code and you build/run XCTest in Xcode (⌘B / ⌘U) and paste results back — or I can drive Xcode on your Mac via computer use if you enable it. I won't claim iOS builds or tests pass without that evidence.
2. **Time-box vs. the prompt pack.** Seven phases with approvals between every step is thorough but will likely exceed 2–3 hours. The assignment is fine with that if it's reported honestly. I suggest tracking actual time per phase from now on for `AI_USAGE.md`.
3. **Fake Store availability.** If it's down during review, the app shows errors. Mitigations (timeouts, clear errors, maybe cache) are planned; a bundled fixture-based provider for offline demo is a possible "next day" item.
4. **Git deletions.** File moves (A18) and some git operations need delete permission in your folder; I'll ask once when we get there.

---

## 15. Decisions needed from you before Phase 2

1. **A2** — "Top rated" in a category = curated featured products in that category (recommended), or rank by Fake Store rating?
2. **A6** — Contact fields: name + email required, phone + message optional. OK?
3. **A7** — Local email via SMTP + Mailpit (Docker). OK for the reviewer to need Docker, or prefer a no-Docker option?
4. **A12** — Missing featured product: skip and log (recommended), or fail the request?
5. **A15** — iOS 16+ deployment target?
6. **A18** — Monorepo with `ios/` and `backend/`?
