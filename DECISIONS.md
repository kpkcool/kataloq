# Kataloq – Decisions and Assumptions

> Assumptions, decisions and trade-offs for Kataloq. Written during planning and updated as the backend (Phase 3) and iOS app (Phase 4) were built; §6 records where the implementation refined the plan and why.

## 1. Technology choices

| Choice | Reason |
|---|---|
| **iOS app in Swift + UIKit** | The assignment lets us pick the client. Native iOS is my strongest platform, so I can defend every line. UIKit (rather than SwiftUI) gives explicit control over lifecycle, navigation and list performance, and fits MVVM-C cleanly. iOS 16 minimum: async/await and modern collection view APIs, without excluding many devices. |
| **MVVM-C** | ViewModels hold state and logic with no UIKit import, so they can be unit tested. Coordinators keep navigation out of ViewControllers, so screens are reusable and flows can change (e.g. deep links) without touching screens. |
| **Node.js 26 LTS + TypeScript backend** | TypeScript strict mode catches contract mistakes at compile time; Node is the backend option in the brief with the fastest path to a tested REST API; it runs anywhere on AWS (ECS, App Runner, Lambda with an adapter). |
| **Express 5, zod, nodemailer, express-rate-limit** | Each removes code we'd otherwise write and test ourselves; all are widely known. Native `fetch` instead of axios; no DI framework; no logger library. |
| **vitest + supertest / XCTest** | Fast TS-native tests without extra config; real HTTP-level integration tests; XCTest is the platform standard with no dependencies. |

## 2. Architectural decisions

| # | Decision | Why | Trade-off |
|---|---|---|---|
| AD-1 | **The iOS app only talks to `kataloq-api`, never Fake Store** | Required by the brief, and the right boundary anyway: the data source is expected to change, and changing it must not need an app release. The backend is the anti-corruption layer. | One extra hop of latency. |
| AD-2 | **`ProductProvider` and `EmailProvider` interfaces** owned by the domain; Fake Store and SMTP are adapters | The brief says the data source and email provider will change. Services depend on the interfaces; only the composition root picks the adapters. | Two small interfaces. Deliberately **not** abstracting things that aren't expected to change. |
| AD-3 | **Our own API contract and domain model** (camelCase, string IDs, `price { amount, currency }`, `rating { average, count }`, category `{ id: slug, name }`) | Fake Store's shapes (numeric IDs, `rate`, category names with spaces and apostrophes, a misspelt "jewelery") shouldn't leak into the app. String IDs mean a future source with SKUs/UUIDs doesn't break the contract. | Mapping code in the adapter (tested). |
| AD-4 | **Business rules live in the backend** (featured selection, category ranking, search) | One source of truth for every future client (web, Android); rules can change without an app release. | Client can't work offline. Not required. |
| AD-5 | **Pure domain functions** for ranking, search matching and enquiry validation | The most important rules are the easiest to test exhaustively. | — |
| AD-6 | **Caching decorator** (`CachingProductProvider`, 60 s in-memory TTL) around the product provider. Caches successful results only; failures and not-found results are never cached; concurrent misses for the same key share one in-flight upstream request (single-flight); 500-entry cap. | Fake Store is a free public API with variable latency; the catalogue is tiny. As a decorator implementing the same interface, it keeps caching out of business logic and the adapter, and can be removed (`PRODUCT_CACHE_TTL_SECONDS=0`) or replaced (e.g. Redis) without touching services. Single-flight stops a burst of cold requests from stampeding the upstream. | Data up to 60 s stale (e.g. a deleted featured product may show for up to 60 s); cache is per process and lost on restart. |
| AD-7 | **Single `AppCoordinator`** | Five screens and one modal flow. Child coordinators would add lifecycle code without benefit at this size. | Will need splitting (e.g. an `EnquiryCoordinator`) as flows grow. |
| AD-8 | **Closure-based ViewModel → ViewController binding** with a `LoadState` enum | iOS 16 rules out Observation; Combine adds machinery we don't need. A closure plus `[weak self]` is easy to read and test. | Less composable than Combine for complex reactive screens. |
| AD-9 | **No DTO layer on iOS** | The backend already maps to our contract; a second mapping would duplicate it. | If the API ever diverges from screen needs, mapping goes in repositories. |
| AD-10 | **Versioned API (`/api/v1`) and a uniform error body** `{ error: { code, message, requestId, details? } }` | Clients branch on stable `code`s, not messages; `requestId` links a user report to server logs; versioning lets the contract evolve. | — |
| AD-11 | **Config via environment variables, validated at startup** | 12-factor, works the same locally, in Compose and on AWS; misconfiguration fails at boot instead of at the first request. | — |
| AD-12 | **Monorepo** (`ios/`, `backend/`, `docs/`) | One repo, one PR, one README, as the submission requires; API and client change together. | Larger PR. |
| AD-13 | **`docker compose up --build` runs the backend and Mailpit** (SMTP + web inbox); iOS runs from Xcode. Every variable has a default in Compose, so no `.env` is needed to start. | One command meets the "running in under 10 minutes" rule; the backend's Dockerfile doubles as the AWS deployment artefact. | Reviewer needs Docker. |
| AD-15 | **Product images are loaded by the app directly from the `imageUrl` the backend returns** (no image proxy). | The brief's rule is that product *data* must go through our backend; the image URL **is** backend-supplied data, and the bytes are static assets. Serving images from a dedicated host is how production catalogues work. A proxy would add ~1 h of streaming, size-limit and SSRF-safety code off the critical path. | The app makes image GETs to the image host (today `fakestoreapi.com/img/…`). When the data source changes, images move to our own CDN / object storage (e.g. S3 + CloudFront) and only the URLs change. |
| AD-16 | **Fake Store bot challenges are surfaced, not bypassed.** A Cloudflare `403` challenge (`cf-mitigated: challenge`) is mapped to `502 UPSTREAM_UNAVAILABLE` with a clear log line. Requests send honest headers (`Accept: application/json`, `User-Agent: kataloq-api/<version>`). | Evading a site operator's bot protection isn't acceptable engineering. Node `fetch` to Fake Store was verified to work (HTTP 200) on 2026-11-19, so no fallback data source was built. | The demo depends on Fake Store accepting requests from the reviewer's network. A fixture-backed provider is the first "next day" item. |
| AD-14 | **No UI test target**; all XCTest tests use mocked networking/repositories. | UI tests against a live backend are slow and flaky for a PoC; the critical path is covered by ViewModel, repository, networking and coordinator tests plus the manual E2E checklist. | No automated end-to-end UI coverage. |

## 3. Assumptions (where the acceptance criteria were unclear)

| # | Assumption | Reason |
|---|---|---|
| AS-1 | **Home "top rated" = 5 manually curated product IDs**, configured in `FEATURED_PRODUCT_IDS`, shown in configured order. | The criterion says *"I have chosen 5 products"* — a human choice, not a computed one. Env config needs no admin UI or database; later it can move to a CMS behind the same service method. |
| AS-2 | **Category "top rated" = computed**: all products in the category are ranked by rating average (desc), then rating count (desc); products tied on both keep their data-source order. The first 3 (configurable, `CATEGORY_TOP_RATED_COUNT`) are shown as **"Top Rated"**; the rest as **"All Products"** in the same order. One sorted list split in two, so no product appears twice. A category with 3 or fewer products shows only "Top Rated". | "Top rated for that category" can't mean the 5 global picks: most categories would have none. Ranking by rating is objective and needs no extra curation. **This means "top rated" means different things on Home (curated) and Category (computed) — a deliberate distinction.** |
| AS-3 | Category links appear on Home; categories come from the data source, not hardcoded. | The criterion needs an entry point; hardcoding would break when the data source changes. |
| AS-4 | **Search** = trimmed, case-insensitive substring match of the whole term against title, description and category name; runs on the search button (keyboard Search), not as-you-type; blank terms aren't sent (client) and are rejected (server, 400); max 100 chars; results keep the data source's original order — no relevance scoring. | Simplest rule that satisfies "text matching", predictable and testable. Matching descriptions broadens results — accepted. Relevance ranking is out of scope for ~20 products. |
| AS-5 | The details screen fetches the product by ID rather than reusing list data. | Works from any entry point (and future deep links); data source can return richer details later. |
| AS-6 | **Enquiry fields**: name (required), email (required), phone (optional), message (optional); product ID sent automatically. Client validation is for UX; backend validation is authoritative. | "Contact details" needs at least a name and a way to reply; optional fields shouldn't block a lead. |
| AS-7 | "The sales inbox will receive an email" = the email provider **accepted** the message. Only then does the app show "Thank you". The API returns `202 Accepted`. | Inbox delivery can't be observed synchronously; provider acceptance is the standard success signal. A provider failure is never reported as success. |
| AS-8 | The sales inbox is `SALES_INBOX_EMAIL`; locally it's captured by **Mailpit** (Docker), viewable at `http://localhost:8025`. | Free, no accounts; exercises the real SMTP path. |
| AS-9 | **Documented exception to "exactly five":** exactly 5 unique featured IDs are enforced at startup (the backend refuses to start otherwise), so Home normally shows exactly 5. If a configured product later becomes unavailable upstream, it is **skipped and a warning is logged**; the endpoint then returns fewer than 5. **No other product is ever substituted**: the owner chose these 5, and silently picking a replacement would misrepresent that choice. An upstream outage is *not* treated as "unavailable"; it returns 502/504. | Partial content beats an error page, but hiding an outage or overriding the owner's choice would mislead. |
| AS-10 | Prices are shown as dollars to 2 decimals via one formatter driven by the `currency` field (USD for Fake Store). | Placeholder data; one place to change. |
| AS-11 | iPhone, portrait-first, iOS 16+. | Brief targets the simulator; iPad optimisation not needed for a PoC. |

## 4. Requirements simplified or dropped

| Item | What we did | Why |
|---|---|---|
| Enquiry persistence | Not stored; the email is the only record. | No requirement; avoids a database in the PoC. Risk: if email fails the user is told and must retry. |
| Search relevance | No ranking or fuzzy matching. | Not in the criteria; catalogue of ~20 items. |
| Pagination | None. | ~20 products. Lists are wrapped in objects so pagination fields can be added later without breaking clients. |
| Auth, accounts, cart, wishlists, analytics | Out of scope. | Not in the criteria. |
| Infrastructure as code | None; a backend `Dockerfile` only. | Brief only requires AWS compatibility *if* infra is included; time-box. |
| Automatic retries | None; user-initiated retry only. | POST enquiry isn't idempotent — a blind retry could send two emails. |
| UI test target | Removed (`KataloqUITests`). | Template only; would need a running backend. E2E covered by the manual/scripted checklist (AD-14). |
| Visual design | Clean system styling via a central `Theme`; no custom design. | Creative work is happening separately; the brief expects the look and feel to change. |

## 5. Notes for the interview

- **Fake Store quirk:** `GET /products/<unknown id>` returns `200` with an empty body, not `404` (verified 2026-11-19). The adapter converts this to "not found" so the quirk never leaks past it.
- **"Top rated" means two different things, deliberately:** curated on Home (the owner's choice), computed by rating on Category pages.
- **Product images:** loaded directly from the backend-supplied URL (AD-15). The rule against calling Fake Store from the app covers product data, not static image delivery. Future: our own image CDN / object storage.
- **Fake Store sometimes returns a Cloudflare challenge** (`403`, `cf-mitigated: challenge`, seen on 2026-11-19). We surface it as 502 and don't try to bypass it (AD-16).

## 6. Implementation notes

### Backend (Phase 3)

| Decision | Detail | Why |
|---|---|---|
| Fake Store adapter filters `/products` for a category instead of calling `/products/category/{name}` | One upstream request instead of two (no slug → raw-name lookup) and no URL-encoding of names like `men's clothing`. | Fake Store has ~20 products. The `ProductProvider` interface still lets a large-catalogue provider query by category. |
| List responses tolerate individual bad items | An item failing schema validation is skipped and logged; a non-array body is an error. | One malformed record shouldn't take down the whole catalogue. |
| Only `https` image URLs are passed to clients | Anything else becomes `null` and the app shows a placeholder. | iOS ATS blocks plain http anyway; avoids mixed content. |
| Configuration is validated at startup with zod | Empty values (`VAR=`) mean "use the default". Invalid values stop the process with a list of problems. | Fail fast instead of failing at the first request; works the same in Compose and on AWS. |
| Category page checks the category exists **before** fetching its products | Unknown IDs return 404 after one (cached) category lookup. | Made-up category IDs never reach the data source or create cache entries, so they can't be used to flush the cache. |
| Featured products are fetched in parallel by ID | `Promise.all` over the 5 configured IDs; `null` → skip + warn; any upstream error fails the request. | Five independent lookups; an outage must surface as 502/504, not as "4 products". |
| Search uses `String.includes`, not a RegExp built from input | `(` or `.*` are matched literally. | No regex injection or ReDoS from user input. |
| One controller + router per area (catalogue, enquiries) instead of one file per resource | Two small files instead of six. | Fewer files to navigate for 6 endpoints; split when an area grows. |
| Request ID + request logging in one middleware (`requestContext`) | Reuses a client `X-Request-Id` only if it matches a safe pattern; logs method, path (from `originalUrl`, no query string), status, duration. | One concern ("per-request context"); no log injection; search terms never logged. |
| `POST /enquiries` returns **202 Accepted** | Sent only after the SMTP server accepted the message. | We can confirm acceptance, not inbox delivery (AS-7). Any provider failure becomes `502 EMAIL_DELIVERY_FAILED`; verified live by stopping Mailpit. |
| Enquiry email is plain text; Reply-To is the bare validated customer address | Subject built from the product title with line breaks removed. | No HTML/markup injection; no header injection via names or titles. |
| Enquiry rejects non-JSON bodies with 415 | `req.is('application/json')` check before validation. | Clear error instead of a confusing "fields missing" 400. |
| Rate limit 5 enquiries/min per IP (`express-rate-limit`, in memory) | Standard `RateLimit` headers + `Retry-After`; catalogue endpoints are not limited. | Spam protection for a form that sends email. In-memory and per instance; behind Docker's port mapping all local clients share one IP, so locally it's effectively global. |
| Email transport built separately from the SMTP adapter | `smtpTransport.ts` wraps nodemailer; `SmtpEmailProvider` depends on a 1-method `MailTransport` interface. | Adapter logic (failure → `EmailDeliveryError`, rejected recipients) is unit-tested without nodemailer. |
| Logger records `code` and inner errors | `ECONNREFUSED` etc. are visible even when Node throws an `AggregateError` with an empty message. | Found in the live Mailpit-down test: the first version logged an empty message. |
| Mailpit pinned by image digest in Compose | Exact image every time. | Reproducible reviewer setup. |
| Backend image: multi-stage `node:26-alpine`, production deps only, runs as `node` (non-root) | Same image runs locally and on ECS/App Runner. | Smaller attack surface; AWS-compatible. |
| JSON-lines logger instead of a logging library | ~50 lines, injectable, silent in tests. | Avoids a dependency; JSON lines are what CloudWatch expects. |

### iOS implementation notes (Phase 4)

| Decision | Detail | Why |
|---|---|---|
| Explicit `@MainActor`, not Xcode 27's "main actor by default" | The template's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` was removed; ViewModels, coordinator and UI are marked `@MainActor`; networking types are `Sendable`. | Networking and decoding aren't tied to the main thread, and isolation is visible in the code (easier to explain and review). |
| Programmatic UIKit, no storyboard | `SceneDelegate` builds the window; `Main.storyboard` removed. | Views and constraints are reviewable in diffs; no storyboard merge conflicts. |
| ViewModel → View binding with a state enum and an `onStateChange` closure | `LoadState<Value>` (idle/loading/loaded/empty/failed); Search and Enquiry have their own state enums because they have more states. | No Combine needed on iOS 16 (Observation is iOS 17+). Tests just `await viewModel.load()` and assert `state`. |
| Load tasks capture the ViewModel, not the ViewController | `Task { await viewModel.load() }`, cancelled in `deinit`. | Leaving a screen deallocates it and cancels its request; cancellation never shows an error. |
| Search on Home, as you type, plus the keyboard's Search button; a new search cancels the previous one | Engineer's decision on 2026-11-20 (replacing a separate Search screen that ran only on the Search button). The search bar sits at the top of Home; results show over Home in the same screen. Typing searches after a 300 ms pause; the Search key searches immediately; clearing the field returns to Home. Matching stays on the backend. Blank / >100-char terms never reach the backend. | Matches common shopping apps. Still satisfies FR-4 (the Search button triggers a search). The pause keeps it to about one request per term, and cancellation means a slow old response can't overwrite newer results. iOS 26 would otherwise place the search field at the bottom of the screen, so the bar is pinned under the title. |
| Product detail fetches by ID | Even when the list already had the product. | Same behaviour from any entry point (incl. future deep links). |
| Enquiry flow: modal sheet with its own navigation controller; success **replaces** the form with Thank you | Cancel/Done dismiss; swipe-to-dismiss is blocked while sending; no automatic retries. | There is no "back" to a sent form, and each submit sends a real email. |
| Client validation mirrors the backend; server field errors shown inline | `EnquiryFormValidator`; a 400 with `details` maps onto the same fields. | Fast feedback, while the backend stays authoritative. |
| Home "Featured" and Category "Top Rated" as horizontal, snapping carousels; "All Products" and search results as a 2-column grid | Engineer's UI direction after the first screenshot ("horizontal scrolling like shopping apps"). Shared `LayoutSections`. | Familiar shopping-app pattern. The first grid used `repeatingSubitem:count:` and overflowed the screen; items are now explicitly half-width with insets. |
| Home shows Featured **and** an "All Products" grid (`GET /api/v1/products`, data-source order) | Engineer's decision on 2026-11-20, after seeing Home with only 5 products and empty space. Featured stays first, so the assignment's "5 chosen products" are still the first thing shown. Featured items also appear in the grid (separate diffable item cases). | Familiar shopping-app home; one extra cached backend call. |
| Category icons mapped from category id; unknown ids get a generic tag icon | Presentation-only mapping. | Nicer chips without coupling behaviour to Fake Store's category list. |
| Lists drop duplicate product IDs before display | Keeps first occurrence and order. | Diffable data sources crash on duplicates; a malformed response must not crash the app (code review R1). |
| No DTO layer, and `ProductCategory` instead of `Category` | Models decode our API directly; `Category` would clash with the Objective-C runtime type. | The backend is already the anti-corruption layer. |
| One product card design system | `ProductCardView` composed of `ProductImageView`, `ProductTitleView`, `ProductPriceView`, `ProductRatingView`; two styles: **featured** (carousel; width chosen so two cards and 30% of the third are visible, about 144–172 pt across iPhone sizes) and **standard** (2-column grid, equal 14 pt column and row gaps). Each card is a white 20 pt rounded surface with a hairline border and one shared soft shadow (black, 6%, radius 10, y 3); the shadow sits on an outer view with an explicit `shadowPath` and the rounded surface clips inside it, so the shadow is never clipped and isn't recomputed while scrolling. Tokens in `Theme.ProductCard`; colours follow the spec in Light Mode and system colours in Dark Mode (engineer's decision). Product detail reuses the image and rating components. | One component for Home, Category and Search, so spacing and typography can't drift. Cards only display a `ProductCardViewData` built by ViewModels: no business logic or navigation in views; taps still go through the coordinator. |
| Image loading: memory cache + one download per URL in flight | `URLSessionImageLoader` shares an in-flight download between cards showing the same image and decodes off the main thread; `ProductImageView` cancels on reuse and ignores late results for a URL it no longer shows. | Same product in Featured and All Products downloads once; fast scrolling never shows the wrong image. Disk cache is still a next-day item. |
| Unit tests skip the real UI | `SceneDelegate` installs an empty root controller when running under XCTest. | Tests never start the app's network calls. |

## 7. Security basics

- Input validation on every endpoint (zod); request body capped at 10 KB.
- Header-injection protection: line breaks rejected in name/email/phone; customer input never used in SMTP headers except a validated `Reply-To`.
- Per-IP rate limit on `POST /enquiries` (default 5/min). In-memory: fine for one instance, needs a shared store (Redis / API Gateway throttling) for more.
- No secrets in the repo; `.env.example` only; SMTP credentials optional and env-only.
- No PII or request bodies in logs; no stack traces or upstream details in responses.
- iOS ATS stays on; only local networking is allowed for the simulator.

## 8. How the design supports growth

| Expected change | What changes | What doesn't |
|---|---|---|
| New product data source | One new `ProductProvider` adapter + config | Services, API contract, iOS app |
| New email vendor (e.g. SES) | One new `EmailProvider` adapter + env vars | Enquiry rules, API, app |
| New look and feel | `Theme` + reusable components | ViewModels, networking, backend |
| Featured products managed by staff | `getFeatured` reads from a CMS/DB instead of env | Endpoint, app |
| More clients (web, Android) | Consume the same `/api/v1` | Business rules (already server-side) |
| More traffic | Shared cache, shared rate-limit store, horizontal scaling (stateless API) | Code structure |

## 9. What I'd do next with another day

1. Persist enquiries and send email from an outbox with retries (no lost leads when the provider is down); add an idempotency key to `POST /enquiries`.
2. OpenAPI spec generated from the zod schemas; contract tests shared by iOS fixtures and the backend.
3. CI (GitHub Actions): backend typecheck + tests, `xcodebuild test` on a simulator.
4. An opt-in fixture-backed `ProductProvider` (`PRODUCT_PROVIDER=fixture`) for offline demos, deterministic E2E tests, and networks where Fake Store's Cloudflare protection challenges requests. Considered during planning and deferred: Node `fetch` reached Fake Store fine, and it's off the acceptance-criteria path.
5. Snapshot tests for every screen and an XCUITest smoke test against a fixture backend; an image disk cache; a full accessibility audit.
6. Move the enquiry rate limiter in front of body parsing and onto a shared store (Redis / API Gateway) for multiple instances.
7. Deploy: backend container to AWS App Runner/ECS, SES as `EmailProvider`, secrets in SSM/Secrets Manager.

## 10. Time spent

Wall-clock windows from the working session on 2026-11-19 (IST). They include time spent waiting for test runs on the Mac; **the engineer should adjust these to actual effort before submitting.**

| Activity | Window | Approx. |
|---|---|---|
| Planning: requirements analysis, architecture, decisions | 16:17 – 17:00 | 45 min |
| Building: backend (5 increments, tested after each) | 17:00 – 18:30 | 1 h 30 min |
| Building: iOS app (5 screens) | 21:16 – 22:56 | 1 h 40 min |
| Testing and reviewing: code review, fixes, verification script, docs | 22:56 – end | *to fill in* |
| **Total** | | **≈ 4 h +** (over the 2–3 h guide; the full planning/review process and step-by-step verification were the main reasons) |
