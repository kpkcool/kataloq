# Kataloq – Product Catalogue Platform
## Phase 2: Architecture

Status: **Approved 2026-11-19 (revision 3)** · Builds on `REQUIREMENTS.md` + decisions D1–D14 approved on 2026-11-19 (D15 proposed) · No implementation code has been written.

**Changes in revision 2:** D7–D12 incorporated (category top 3, "Top Rated"/"All Products" sections, search order, Compose with backend + Mailpit, cache design, UI test target removed). Fake Store behaviour verified (§3). Conflict check added (§11).

**Changes in revision 3:** conflicts C1–C3 resolved (D13 featured-count exception, D14 image delivery). Toolchain pinned to what's verified on the development Mac (Xcode 27.2, Node 26 LTS). New risk R1: Fake Store sometimes answers with a Cloudflare bot challenge (403). Mitigation proposed as D15 (§11). Environment checklist added (§12).

Code blocks below are **contracts** (interfaces, types, JSON shapes) so we can agree on the boundaries. They are not implementation.

---

## 0. Approved decisions this design is based on

| # | Decision |
|---|---|
| D1 | Home = 5 manually configured featured IDs. Category = products ranked by Fake Store `rating.rate` desc, then `rating.count` desc; top-rated section first, remaining products after, no duplicates. Curated (Home) vs computed (Category) distinction documented. |
| D2 | Enquiry fields: name (required), email (required), phone (optional), message (optional). Validation on iOS and backend; **backend is authoritative**. |
| D3 | Mailpit via Docker Compose; backend sends SMTP to Mailpit; reviewer reads email in Mailpit web UI. Email behind a replaceable provider interface. |
| D4 | Missing featured product → skip + log warning; endpoint still succeeds. Upstream failures handled and documented. |
| D5 | iOS 16.0 minimum; Swift, UIKit, MVVM-C, URLSession, Swift Concurrency. |
| D6 | One repo `kataloq`: `ios/`, `backend/`, `docs/`; root README.md, DECISIONS.md, AI_USAGE.md, AGENTS.md, docker-compose.yml, .gitignore. |
| D7 | Category "Top Rated" = exactly **3** products (fewer only if the category has fewer than 3), configurable via `CATEGORY_TOP_RATED_COUNT`. |
| D8 | All category products sorted by `rating.rate` desc, then `rating.count` desc. First 3 → **"Top Rated"**; the rest → **"All Products"** in the same order. No duplicates. |
| D9 | Search keeps Fake Store's original order after filtering. No relevance scoring. |
| D10 | `docker compose up --build` starts the backend, Mailpit SMTP and the Mailpit web inbox. The iOS app runs separately from Xcode. |
| D11 | 60 s in-memory cache of Fake Store data: cache successes only, expire after 60 s, never cache failures, de-duplicate concurrent misses, isolated from business logic. |
| D12 | Remove the `KataloqUITests` target and template code; keep `KataloqTests` with mocked networking (no running backend needed). |
| D13 | Exactly 5 featured IDs, validated at startup. Normally 5 are returned; an unavailable one is skipped with a warning, so the endpoint may temporarily return fewer. Never substitute another product. Documented as an exception in DECISIONS.md. |
| D14 | **Images (option A):** the backend returns the image URL in `imageUrl`; the app downloads image bytes directly from that host. The "no direct Fake Store calls" rule covers product **data** retrieval, not static image delivery. No image proxy in the MVP; a dedicated image CDN / object storage (e.g. S3 + CloudFront) is the future path. |
| D15 | ~~Opt-in `fixture` product provider~~ — **not built.** Node `fetch` to Fake Store verified (HTTP 200, 2026-11-19); deferred to "next day". Cloudflare-challenge detection kept. |

---

## 1. System architecture

```
┌──────────────────────────┐  HTTPS/JSON (REST, /api/v1)   ┌──────────────────────────────────────────────┐
│  Kataloq iOS (UIKit)     │ ────────────────────────────▶ │  kataloq-api (Node.js + TypeScript, Express) │
│  View ↔ ViewModel        │                               │                                              │
│  Coordinator             │                               │  routes → controllers → services             │
│  Repository → APIClient  │ ◀──────────────────────────── │                │               │             │
└──────────────────────────┘   Kataloq domain JSON only    │                ▼               ▼             │
                                                           │       ProductProvider     EmailProvider      │
                                                           │       (interface)         (interface)        │
                                                           │           │                   │              │
                                                           │  CachingProductProvider        │              │
                                                           │           │                   │              │
                                                           │  FakeStoreProductProvider  SmtpEmailProvider │
                                                           └───────────┼───────────────────┼──────────────┘
                                                                       ▼                   ▼
                                                              fakestoreapi.com      Mailpit (SMTP :1025,
                                                                                    web UI :8025)
```

### Layer responsibilities

| Layer | Owns | Must not |
|---|---|---|
| iOS app | Presentation, navigation, client-side validation for UX, image loading, local UI state | Call Fake Store; contain business rules (ranking, featured selection, search matching) |
| `kataloq-api` HTTP layer (routes/controllers) | HTTP parsing, request validation, status codes, response shaping | Contain business rules or talk to external services |
| Services | Business rules: featured selection, category ranking/partition, search, enquiry orchestration | Know about HTTP, Express, Fake Store JSON or SMTP |
| Domain (pure functions + types) | `Product`, `Category`, ranking, search matching, enquiry validation schema | Do I/O |
| Providers (interfaces) | The contract a data source / email vendor must satisfy | — |
| Adapters | Translate one external system to/from the domain (Fake Store → `Product`; `EnquiryEmail` → SMTP) | Leak vendor types upward |

### Dependency direction

Everything points **inwards** to the domain and the provider interfaces:

```
routes → controllers → services → domain
                          └──→ ProductProvider / EmailProvider (interfaces, owned by the domain)
                                     ▲                ▲
              FakeStoreProductProvider        SmtpEmailProvider   (adapters depend on the interfaces)
```

Services depend on interfaces, never on adapters. Only the **composition root** (`container.ts`) knows which adapter is used. That's dependency inversion where it pays off (two volatile externals), and nowhere else.

### Communication
- iOS ↔ backend: REST over HTTP, JSON, versioned prefix `/api/v1`. Simulator talks to `http://localhost:3000`.
- Backend ↔ Fake Store: native `fetch` (Node 26 LTS) with `AbortSignal.timeout`, `Accept: application/json` and an honest `User-Agent: kataloq-api/<version>`.
- iOS ↔ image host: the app downloads image bytes directly from the `imageUrl` the backend returned (D14). No product data comes from that host.
- Backend ↔ Mailpit: SMTP via `nodemailer`.

### Error propagation (one example end to end)

```
Fake Store times out
  → FakeStoreProductProvider throws UpstreamTimeoutError            (adapter translates fetch/AbortError)
  → CatalogueService does not catch it (not its concern)
  → Express 5 forwards the rejected promise to errorHandler
  → 504 { "error": { "code": "UPSTREAM_TIMEOUT", "message": "...", "requestId": "..." } }
  → iOS URLSessionAPIClient decodes error body → APIError.server(status: 504, code: .upstreamTimeout, …)
  → ViewModel maps to .failed(message: "Products are taking too long to load. Please try again.")
  → ViewController shows StateView with Retry
```

Each layer translates errors into **its own vocabulary** and the client never sees stack traces, vendor messages or internal hostnames.

### How providers are replaced
- **New product source** (e.g. Shopify, a DB, a CMS): write `XProductProvider implements ProductProvider`, change one line in `container.ts` (or select by `PRODUCT_PROVIDER` env var). Services, API contract and iOS app unchanged.
- **New email vendor** (e.g. AWS SES): write `SesEmailProvider implements EmailProvider`, add its env vars. Enquiry rules unchanged.
- **New look and feel**: iOS `Theme` (colours, fonts, spacing) + reusable components; screens don't hardcode styling.

---

## 2. iOS MVVM-C architecture

### Responsibilities

| Component | Responsibility | Notes |
|---|---|---|
| **ViewController** | Owns views, layout, binds to ViewModel state, forwards user intents. Owns the `Task` it starts and cancels it on `deinit`. | No networking, no formatting rules, no navigation decisions |
| **Views** | Reusable UI: `ProductTileCell`, `CategoryChipCell`, `RatingView`, `StateView` (loading / empty / error+retry), `FormFieldView` | Configured from small view-data structs |
| **ViewModel** | `@MainActor final class`. Holds screen state, calls repositories, maps models → display values (price string, rating text), validation, emits navigation intents via closures | **No `import UIKit`** → unit-testable without UI |
| **Coordinator** | Creates VCs + VMs, injects dependencies, wires navigation closures, pushes/presents | One `AppCoordinator` (see below) |
| **Models** | `Product`, `Price`, `Rating`, `Category`, `CategoryProducts`, `EnquiryRequest`, `EnquiryConfirmation` — `Codable`, `Equatable`, `Hashable`, `Sendable` value types | Match backend contract 1:1 |
| **Networking** | `APIClient` protocol + `URLSessionAPIClient`; `Endpoint` describes method/path/query/body; `APIError` | One generic `send(_:)` method |
| **Repositories** | `ProductRepository`, `EnquiryRepository` protocols + `Remote…` implementations: build endpoints, call `APIClient` | The seam ViewModels are tested against |
| **Dependency container** | `AppDependencies` struct built once in `SceneDelegate` | Plain struct, no DI framework |
| **Image loading** | `ImageLoader` protocol + `URLSessionImageLoader` with `NSCache` | Downloads from the backend-supplied `imageUrl` (D14). Cells cancel loads on reuse; failure or `nil` URL → placeholder. Only `https` URLs are loaded. |

### Why no separate DTO layer on iOS
The backend already maps Fake Store into **our** contract; it is the anti-corruption layer. Adding DTO → domain mapping on iOS would duplicate that for no benefit. If the API ever diverges from what screens need, mapping goes in the repository.

### ViewController ↔ ViewModel binding

iOS 16 rules out the Observation framework. Options were Combine `@Published` or a plain closure. **Choice: a state enum + `onStateChange` closure.** It's the least machinery, easy to explain, and tests just `await` the ViewModel's async method and assert `state`.

```swift
// Contract sketch
enum LoadState<Value: Equatable>: Equatable {
    case idle, loading, loaded(Value), empty(message: String), failed(message: String)
}

@MainActor protocol HomeViewModelType: AnyObject {
    var state: LoadState<HomeContent> { get }
    var onStateChange: ((LoadState<HomeContent>) -> Void)? { get set }
    var onProductSelected: ((Product.ID) -> Void)? { get set }   // navigation intent
    var onCategorySelected: ((Category) -> Void)? { get set }
    var onSearchSelected: (() -> Void)? { get set }
    func load() async
    func didSelectProduct(at indexPath: IndexPath)
}
```

- VC: `viewModel.onStateChange = { [weak self] in self?.render($0) }`; starts `loadTask = Task { await viewModel.load() }`, cancels in `deinit`.
- Cancellation (`CancellationError`, `URLError.cancelled`) is **not** shown as an error.
- Search VM cancels the previous search task when a new search starts.

### Navigation

Single **`AppCoordinator`** owning a `UINavigationController`. A second coordinator for a 2-screen modal adds lifecycle code without benefit at this size; it's the first thing to split out as flows grow.

| From | Trigger | Coordinator action |
|---|---|---|
| Home | product tile | push `ProductDetail(id)` |
| Home | category chip | push `Category(category)` |
| Home | search bar (typing / Search key) | no navigation: results appear over Home (`SearchViewController` is the `UISearchController`'s results controller) |
| Category / Search results | product tile | push `ProductDetail(id)` |
| ProductDetail | Enquire | present `Enquiry(product)` modally in its own `UINavigationController` |
| Enquiry | submit succeeded | replace form with `ThankYouViewController` in the modal stack (no back to the submitted form) |
| ThankYou / Enquiry | Continue shopping / Close (✕) | dismiss modal |

ViewModels expose intents as closures; the coordinator assigns them with `[weak self]`. VMs never see `UIViewController`.
Retention: `SceneDelegate` → `AppCoordinator` → `UINavigationController` → VCs → VMs. Closures from VMs back to the coordinator are weak → no cycles.

### Screens

| Screen | Layout | States |
|---|---|---|
| Home | `UICollectionView` + compositional layout + diffable data source: search bar pinned under the large title; categories (horizontal chips), Featured (horizontal carousel of product cards) and All Products (2-column grid) sections | loading, loaded, empty, failed+retry. Categories, featured and all products load concurrently (`async let`) |
| Category | Same tile grid, two sections with headers **"Top Rated"** (`topRated`) and **"All Products"** (`additional`), in the order the backend returns them; an empty section is hidden. The app does no sorting or de-duplication of its own (backend owns the rule). | loading, loaded, empty (category has no products), failed+retry, not-found |
| Search results (on Home) | Results controller of Home's `UISearchController`, 2-column grid. Searches as the user types (300 ms pause, each keystroke cancels the previous search) and immediately on the keyboard **Search** button, the "search button" in the AC. Matching stays on the backend; results in the order returned (Fake Store order, D9). | loading, results, empty ("No products match 'x'"), failed+retry; empty field → back to Home, no request |
| Product detail | `UIScrollView` + `UIStackView`: image, title, price, category, rating, description, sticky **Enquire** button | loading, loaded, not-found, failed+retry |
| Enquiry | Scroll view with `FormFieldView`s (name, email, phone, message), inline errors, Submit with spinner, keyboard avoidance | editing, submitting (button disabled → no double submit), failed (data kept, retry), succeeded → Thank you |
| Thank you | Message + product name + Done | static |

iOS 16 has no `UIContentUnavailableConfiguration` (iOS 17), so `StateView` is a small custom view.

### Configuration
- `API_BASE_URL` build setting → Info.plist key `KataloqAPIBaseURL` (Debug: `http://localhost:3000`).
- Launch-environment override `KATALOQ_API_BASE_URL` for physical devices / tests.
- ATS: `NSAllowsLocalNetworking = YES` only (permits `localhost` http without disabling ATS globally).
- `Main.storyboard` removed; `SceneDelegate` builds the window programmatically.

---

## 3. Backend architecture

### Stack and dependencies (each with a reason)

| Package | Why | Alternative rejected |
|---|---|---|
| `express` v5 | Most widely known Node HTTP framework; v5 forwards rejected async handlers to the error middleware natively | Fastify (fine, less familiar to reviewers); raw `node:http` (reinventing routing) |
| `zod` | One schema gives runtime validation **and** the TS type; used for request bodies, query params, env config and validating upstream Fake Store responses | Hand-written validators (more code, more bugs) |
| `nodemailer` | De facto SMTP client; works with Mailpit locally and any SMTP relay (incl. SES SMTP) | Vendor SDKs (lock-in) |
| `express-rate-limit` | Proven per-IP limiter for the enquiry endpoint | Hand-rolled limiter (more code to test) |
| dev: `typescript`, `tsx`, `vitest`, `supertest`, `@types/*` | Strict TS, fast dev reload, fast TS-native tests, HTTP integration tests | Jest (needs extra TS config) |

No axios (native `fetch`), no DI framework (manual composition root), no logger library (small JSON logger, see below).

### Layers

```
src/
  server.ts            ← process entry: loads config, builds container, listens, handles signals/unhandledRejection
  app.ts               ← createApp(deps): Express app from injected services (used by tests)
  container.ts         ← composition root: config → adapters → services
  config/env.ts        ← zod-validated env → typed Config (fail fast on startup)
  routes/              ← URL → controller mapping
  controllers/         ← parse/validate input, call service, shape response
  services/            ← CatalogueService, EnquiryService
  domain/              ← types, ranking.ts, search.ts, enquiry schema, errors.ts
  providers/
    product/           ← ProductProvider interface, FakeStoreProductProvider, CachingProductProvider
    email/             ← EmailProvider interface, SmtpEmailProvider, enquiry email template
  middleware/          ← requestId, requestLogger, rateLimiter, errorHandler, notFound
  lib/logger.ts
```

### Provider abstractions

```ts
// providers/product/ProductProvider.ts — owned by the domain, implemented by adapters
export interface ProductProvider {
  listProducts(): Promise<Product[]>;
  getProduct(id: ProductId): Promise<Product | null>;        // null = does not exist
  listCategories(): Promise<Category[]>;
  listProductsByCategory(categoryId: CategoryId): Promise<Product[]>;
}
// Throws UpstreamUnavailableError | UpstreamTimeoutError | UpstreamBadResponseError on failure.

// providers/email/EmailProvider.ts
export interface EmailProvider {
  send(message: EmailMessage): Promise<{ messageId: string }>;
}
// Throws EmailDeliveryError if the provider did not accept the message.
```

**`FakeStoreProductProvider`**
- Takes `{ baseUrl, timeoutMs, fetch }` (fetch injectable → mocked in tests).
- Validates every upstream payload with a zod schema; malformed → `UpstreamBadResponseError` (we never pass through garbage).
- Maps Fake Store → domain: `id` number → string, `rating.rate` → `rating.average`, `image` → `imageUrl`, category name → `{ id: slug, name: display }` (e.g. `men's clothing` → `{ id: "mens-clothing", name: "Men's Clothing" }`).
- **Verified 2026-11-19:** `GET /products/999` returns **HTTP 200 with an empty body**, not 404. The adapter treats an empty / `null` body on `GET /products/:id` as "not found" (`null`). A 404 from upstream is treated the same way. This quirk stays inside the adapter.
- **Verified categories:** `electronics`, `jewelery`, `men's clothing`, `women's clothing`. `GET /products/category/{name}` needs the raw name URL-encoded (`men's%20clothing`); the adapter resolves our slug → raw name via `listCategories()` (cached).
- Verified product shape: `{ id, title, price, description, category, image, rating: { rate, count } }`; images are hosted under `https://fakestoreapi.com/img/…` (see §11, C3).
- Non-numeric IDs short-circuit to `null` without an upstream call (Fake Store IDs are numeric; our contract isn't).

### Cache design — `CachingProductProvider` (D11)

A **decorator** implementing the same `ProductProvider` interface and wrapping the Fake Store adapter. Services can't tell it's there; `container.ts` decides whether to wrap (`PRODUCT_CACHE_TTL_SECONDS=0` → not wrapped).

```
CatalogueService ──▶ ProductProvider ◀── CachingProductProvider ──wraps──▶ FakeStoreProductProvider
```

| Rule | How |
|---|---|
| Cache keys | One per method + argument: `products`, `categories`, `category:<id>`, `product:<id>` |
| Cache successes only | A value is stored only after the wrapped call **resolves**. |
| 60 s expiry | Entry stores `expiresAt = now() + ttl`; read checks `now() < expiresAt`. `now` is an injected clock → tests advance time without sleeping. Expired entries are replaced on next read (no background timer). |
| Never cache failures | On rejection the key is removed and the error propagates; the next request retries upstream. |
| Concurrent misses (single-flight) | The map holds the **in-flight promise**, not just values. Ten simultaneous requests for `products` while the cache is cold → one upstream call, all ten await the same promise. If it rejects, all ten get the error and the key is cleared. |
| Not-found results (`null`) | **Not cached.** Otherwise `GET /products/<random>` could grow the cache without bound. Real IDs are bounded by the catalogue size. |
| Size bound | Hard cap of 500 entries (oldest evicted first) as a backstop. Internal constant, not config. |
| Scope / limits | Per-process memory; lost on restart; not shared across instances. Documented; Redis/ElastiCache would be a drop-in replacement decorator. |

Why a decorator rather than caching inside the adapter or the service: the service stays pure business logic; the Fake Store adapter stays a pure translator; caching can be removed, tuned or replaced on its own and tested on its own.

**`SmtpEmailProvider`**
- `nodemailer` transport from config (`SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, optional `SMTP_USER`/`SMTP_PASS`).
- Success **only** when the SMTP server accepts the message; any transport error → `EmailDeliveryError`.

### Services

**`CatalogueService(productProvider, { featuredProductIds, categoryTopRatedCount }, logger)`**

| Method | Rule |
|---|---|
| `getFeatured()` | `getProduct` for each configured ID **in parallel**; preserve configured order; `null` → skip + `logger.warn({ productId }, "featured product unavailable")` (D4). Upstream failure (timeout/5xx) is **not** "unavailable" → propagates → 502/504. |
| `getCategories()` | pass-through |
| `getCategoryProducts(categoryId)` | verify category exists (else `NotFoundError`) → `listProductsByCategory` → `rankByRating` → first *N* (`CATEGORY_TOP_RATED_COUNT`, default 3) = `topRated`, rest = `additional`. One sorted list split at index *N* → disjoint by construction, same order across both sections (D7, D8). A category with ≤ 3 products returns them all in `topRated` and an empty `additional`. |
| `searchProducts(query)` | `listProducts` → `filter(matchesQuery)`. `filter` preserves the data source's order; no re-sorting (D9). |
| `getProduct(id)` | `null` → `NotFoundError` |

**`EnquiryService(productProvider, emailProvider, { salesInboxEmail, fromEmail }, logger, clock, idGenerator)`**
1. Load product (`null` → `NotFoundError` on `productId`).
2. Build `EnquiryEmail` (subject `New enquiry: <product title>`, plain-text body with product id/title/price + customer fields + timestamp + enquiry id; `Reply-To` = customer email).
3. `emailProvider.send(...)`; failure → `EmailDeliveryError` (→ 502). **Never** returns success unless `send` resolved.
4. Log `{ enquiryId, productId, messageId }` — **no PII** (no name/email/phone/message in logs).

### Domain (pure, no I/O — the most heavily unit-tested part)

- `rankByRating(products)`: sort by `rating.average` desc → `rating.count` desc (D8) → **original data-source position** as the final tie-break, so products tied on both keep a stable, predictable order. (JS `Array.prototype.sort` is stable, so this needs no extra code; the test pins it.) Missing rating counts as 0/0.
- `matchesQuery(product, query)`: trimmed, lower-cased (`toLocaleLowerCase('en')`) **substring** match of the whole query against `title`, `description`, `category.name`.
- `enquirySchema` (zod), see §5.

### Validation
- Path/query/body validated in controllers with zod; failures → `ValidationError` with per-field details → 400.
- `express.json({ limit: '10kb' })` → oversized body → 413.
- Unknown body fields are stripped (tolerant of newer clients), not rejected.

### Error handling

```
AppError (abstract: status, code, safe message)
 ├─ ValidationError          400  VALIDATION_ERROR      details: [{ field, message }]
 ├─ NotFoundError            404  PRODUCT_NOT_FOUND | CATEGORY_NOT_FOUND | ROUTE_NOT_FOUND
 ├─ UpstreamUnavailableError 502  UPSTREAM_UNAVAILABLE
 ├─ UpstreamBadResponseError 502  UPSTREAM_BAD_RESPONSE
 ├─ UpstreamTimeoutError     504  UPSTREAM_TIMEOUT
 └─ EmailDeliveryError       502  EMAIL_DELIVERY_FAILED
(+ 413 PAYLOAD_TOO_LARGE, 429 RATE_LIMITED from middleware; anything else → 500 INTERNAL_ERROR, generic message)
```

One `errorHandler` middleware maps errors → JSON. Unknown errors are logged with stack (server side only) and returned as generic 500. `process.on('unhandledRejection'|'uncaughtException')` → log + exit non-zero (let the orchestrator restart; don't run in an unknown state).

### Configuration (`.env.example`, validated at startup)

| Variable | Default (example) | Notes |
|---|---|---|
| `PORT` | `3000` | |
| `LOG_LEVEL` | `info` | `debug`/`info`/`warn`/`error` |
| `FAKE_STORE_BASE_URL` | `https://fakestoreapi.com` | |
| `UPSTREAM_TIMEOUT_MS` | `5000` | integer 100–30000 |
| `PRODUCT_CACHE_TTL_SECONDS` | `60` | integer ≥ 0; `0` disables the cache decorator (D11) |
| `FEATURED_PRODUCT_IDS` | `1,5,9,14,18` | comma-separated, **exactly 5 unique** IDs, else startup fails. Default chosen to cover all 4 categories (1 men's clothing, 5 jewelery, 9 & 14 electronics, 18 women's clothing) — confirmed against live data at the start of Phase 3 |
| `CATEGORY_TOP_RATED_COUNT` | `3` | integer 1–20 (D7) |
| `SMTP_HOST` / `SMTP_PORT` / `SMTP_SECURE` | `localhost` / `1025` / `false` | `mailpit` inside Compose |
| `SMTP_USER` / `SMTP_PASS` | *(empty)* | only for real relays; never committed |
| `EMAIL_FROM` | `Kataloq <no-reply@kataloq.local>` | |
| `SALES_INBOX_EMAIL` | `sales@kataloq.local` | |
| `ENQUIRY_RATE_LIMIT_PER_MINUTE` | `5` | per IP |

### Logging
- Tiny `Logger` interface (`debug/info/warn/error(obj, msg)`) writing one JSON line to stdout (CloudWatch-friendly); injected → silent in tests.
- `requestId` middleware (UUID, echoed as `X-Request-Id` and in error bodies) + request log line (method, path, status, duration).
- Never logged: request bodies, enquiry PII, SMTP credentials.

---

## 4. REST API contract

Base: `http://localhost:3000/api/v1` · JSON · UTF-8 · success bodies are plain objects (lists wrapped in an object so fields like pagination can be added without breaking clients).

**Common error body (all 4xx/5xx):**
```json
{ "error": { "code": "VALIDATION_ERROR", "message": "Some fields are invalid.", "requestId": "3f1c…",
             "details": [{ "field": "email", "message": "Enter a valid email address." }] } }
```
`details` only for `VALIDATION_ERROR`.

### 4.1 `GET /health`
`200 { "status": "ok" }` — for Compose/ECS health checks. Doesn't call upstream.

### 4.2 `GET /api/v1/products/featured`
- Params: none
- `200 { "products": Product[] }` — exactly 5 in the normal case, in configured order. If a configured product no longer exists upstream it's skipped and a warning is logged, so the response can contain fewer than 5 (D4; see §11, C1). An empty list is still `200`.
- Errors: `502 UPSTREAM_UNAVAILABLE | UPSTREAM_BAD_RESPONSE`, `504 UPSTREAM_TIMEOUT`, `500`

### 4.3 `GET /api/v1/categories`
- `200 { "categories": Category[] }`
- Errors: `502`, `504`, `500`

### 4.4 `GET /api/v1/categories/:categoryId/products`
- Path: `categoryId` — slug, `^[a-z0-9-]{1,64}$`
- `200`
```json
{ "category": { "id": "electronics", "name": "Electronics" },
  "topRated":   [ /* first 3 Products of the ranked list (fewer only if the category has < 3) */ ],
  "additional": [ /* every remaining Product, continuing the same ranked order */ ] }
```
- Ranking: `rating.average` desc, then `rating.count` desc (D8). `topRated ∩ additional = ∅` and `topRated ∪ additional` = every product in the category.
- The iOS app labels `topRated` "Top Rated" and `additional` "All Products". The API field keeps the neutral name `additional` (it matches the acceptance criterion's "additional products"; UI copy can change without an API change).
- Errors: `400 VALIDATION_ERROR` (bad slug), `404 CATEGORY_NOT_FOUND`, `502`, `504`, `500`

### 4.5 `GET /api/v1/products/search?q=<term>`
- Query: `q` required, trimmed length 1–100
- `200 { "query": "shirt", "products": Product[] }` (empty array if no match — **not** 404). `query` echoes the trimmed term. Products are in the data source's original order (D9); matching is case-insensitive substring on title, description and category name.
- Errors: `400 VALIDATION_ERROR` (missing/blank/too long), `502`, `504`, `500`

### 4.6 `GET /api/v1/products/:productId`
- Path: `productId` — `^[A-Za-z0-9_-]{1,64}$` (string, source-agnostic)
- `200 { "product": Product }`
- Errors: `400 VALIDATION_ERROR`, `404 PRODUCT_NOT_FOUND`, `502`, `504`, `500`
- Routing note: `/products/featured` and `/products/search` are registered before `/products/:productId`.

### 4.7 `POST /api/v1/enquiries`
- Headers: `Content-Type: application/json`; max body 10 KB
- Body:
```json
{ "productId": "1", "name": "Jane Citizen", "email": "jane@example.com",
  "phone": "+61 400 000 000", "message": "Is this available in blue?" }
```
- `202 Accepted`
```json
{ "enquiryId": "b9e2…", "status": "sent" }
```
  202 because the email provider has **accepted** the message; inbox delivery is asynchronous and not something we can confirm.
- Errors: `400 VALIDATION_ERROR` (with `details`), `404 PRODUCT_NOT_FOUND`, `413 PAYLOAD_TOO_LARGE`, `415` (non-JSON), `429 RATE_LIMITED`, `502 EMAIL_DELIVERY_FAILED`, `502/504` (product lookup upstream), `500`

---

## 5. Data models

### TypeScript (domain = API contract)

```ts
type ProductId = string;           // string so a future source (SKU, UUID) needs no contract change
type CategoryId = string;          // URL-safe slug

interface Price    { amount: number; currency: string }   // currency "USD" for Fake Store (A11)
interface Rating   { average: number; count: number }     // 0–5, count ≥ 0
interface Category { id: CategoryId; name: string }
interface Product {
  id: ProductId; title: string; description: string;
  price: Price; category: Category; imageUrl: string | null; rating: Rating;
}
interface CategoryProducts { category: Category; topRated: Product[]; additional: Product[] }

// Enquiry (zod schema → inferred type)
interface EnquiryRequest {
  productId: ProductId;   // required, same pattern as path param
  name: string;           // required, trimmed, 2–100 chars, no control chars / line breaks
  email: string;          // required, trimmed, ≤254 chars, valid email format, no line breaks
  phone?: string;         // optional; if present: 6–20 chars of digits, spaces, + - ( )
  message?: string;       // optional; ≤1000 chars; line breaks allowed (body only, never a header)
}
interface EnquiryAccepted { enquiryId: string; status: 'sent' }
interface ApiErrorBody { error: { code: string; message: string; requestId: string;
                                  details?: { field: string; message: string }[] } }

// Upstream (adapter-private, never exported past the adapter)
interface FakeStoreProduct { id: number; title: string; price: number; description: string;
                             category: string; image: string; rating?: { rate: number; count: number } }
```

Empty optional strings (`""`) are normalised to `undefined` before validation, so a blank phone field is "not provided", not "invalid".

### Swift (Codable value types)

```swift
struct Product: Codable, Equatable, Hashable, Sendable, Identifiable {
    let id: String
    let title: String
    let description: String
    let price: Price
    let category: Category
    let imageUrl: URL?          // "imageUrl" → URL?; null or invalid string → nil (custom decode, no throw)
    let rating: Rating
}
struct Price: Codable, Equatable, Hashable, Sendable { let amount: Decimal; let currency: String }
struct Rating: Codable, Equatable, Hashable, Sendable { let average: Double; let count: Int }
struct Category: Codable, Equatable, Hashable, Sendable, Identifiable { let id: String; let name: String }

struct FeaturedProductsResponse: Decodable { let products: [Product] }
struct CategoriesResponse: Decodable { let categories: [Category] }
struct CategoryProducts: Decodable, Equatable { let category: Category; let topRated: [Product]; let additional: [Product] }
struct SearchResponse: Decodable { let query: String; let products: [Product] }
struct ProductResponse: Decodable { let product: Product }

struct EnquiryRequest: Encodable, Equatable { let productId: String; let name: String; let email: String
                                              let phone: String?; let message: String? }
struct EnquiryConfirmation: Decodable, Equatable { let enquiryId: String; let status: String }

struct APIErrorResponse: Decodable { let error: Body
    struct Body: Decodable { let code: String; let message: String; let requestId: String?; let details: [FieldError]? }
    struct FieldError: Decodable, Equatable { let field: String; let message: String } }
```

**JSON → Swift mapping**
- The backend uses camelCase, so property names match keys exactly — **no `CodingKeys` and no `keyDecodingStrategy`**, which avoids a class of silent mapping bugs.
- `price.amount` → `Decimal` (no binary floating-point rounding in money); formatted by one `PriceFormatter` using `price.currency`.
- `imageUrl` → `URL?`; the only custom `init(from:)`, so one bad image URL doesn't fail decoding of the whole list.
- `EnquiryRequest` encodes `nil` optionals as absent keys (synthesized `Encodable` uses `encodeIfPresent`); the ViewModel converts blank phone/message to `nil` before building the request.

---

## 6. Dependency injection strategy

**Principle:** inject at the seams where we need to swap or fake something; don't abstract the rest.

| Seam | Backend | iOS | Why it's a seam |
|---|---|---|---|
| Product data source | `ProductProvider` interface | — | Will change (scenario); faked in service tests |
| Email vendor | `EmailProvider` interface | — | Will change (scenario); failure path must be testable |
| HTTP to upstream | injectable `fetch` | — | Adapter tests without network |
| Our API | — | `APIClient` protocol | Repository tests without network |
| Data access for screens | — | `ProductRepository`, `EnquiryRepository` protocols | ViewModel tests with mocks |
| Images | — | `ImageLoader` protocol | Cells testable, cache swappable |
| Time / IDs / logging | `clock`, `idGenerator`, `Logger` | — | Deterministic email content and quiet tests |

- **Backend:** constructor injection; `container.ts` is the only place that `new`s adapters. `createApp(deps)` takes services, so integration tests build the real Express app with in-memory fakes.
- **iOS:** initializer injection. `SceneDelegate` builds `AppDependencies` (config, `URLSessionAPIClient`, repositories, image loader) → `AppCoordinator(dependencies:)` → coordinator builds each VM with the protocols it needs.
- Not abstracted on purpose: services themselves on the backend (tested directly), formatters, validators, coordinators (no protocol per coordinator).

---

## 7. Error-handling strategy

**Backend:** see §3. Rules: errors are typed at the boundary where they happen; services only throw domain errors; one middleware maps them to HTTP; clients only ever see `{ error: { code, message, requestId } }`; no stack traces, upstream messages or hostnames in responses.

**Decisions on specific failure modes**

| Situation | Behaviour |
|---|---|
| Featured ID doesn't exist upstream | Skipped, `warn` logged, 200 with fewer items (D4) |
| Fake Store down / 5xx / non-JSON / schema mismatch | 502 |
| Fake Store slower than 5 s | 504 |
| Email provider rejects / unreachable | 502 `EMAIL_DELIVERY_FAILED`; the app shows an error and keeps the form data |
| Invalid config at startup | Process exits with a clear message (fail fast, not fail later) |

**iOS:**

```swift
enum APIError: Error, Equatable {
    case transport(URLError.Code)          // offline, cannot connect (backend not running), DNS
    case timeout
    case server(status: Int, code: String?, message: String?, fieldErrors: [APIErrorResponse.FieldError])
    case decoding                          // contract mismatch
    case invalidResponse
}
```
- `URLSessionAPIClient` validates status (2xx), decodes the error body for non-2xx, maps `URLError` (`.cancelled` → rethrown as `CancellationError`, so VMs can ignore it).
- Timeouts: `timeoutIntervalForRequest = 15 s` (backend's 5 s upstream timeout + headroom).
- ViewModels map `APIError` → user-facing copy (e.g. "Can't reach Kataloq. Check the server is running and try again."). Server field errors on enquiry are shown inline on the matching field.
- **No automatic retries.** GETs retry via the Retry button. POST enquiry is not idempotent, so a blind retry could send two emails; the user retries deliberately (idempotency key = "next day" item).

---

## 8. Testing strategy

### Backend (vitest + supertest)

| Level | Target | Key cases |
|---|---|---|
| Unit — domain | `rankByRating` | rate desc; count desc as tie-break; full ties keep original order; missing rating sinks; input array not mutated |
| Unit — domain | `matchesQuery` | case-insensitive; matches title / description / category; no match; whitespace trimmed; regex-special characters treated literally |
| Unit — domain | `enquirySchema` | each field valid/invalid; optional blanks → undefined; CR/LF in name/email rejected; length limits |
| Unit — service | `CatalogueService` (in-memory fake provider) | featured: all 5 in configured order; one missing → 4 returned + warning logged; upstream error propagates (not swallowed as "missing"). Category: exactly 3 top rated, rest in `additional` in the same order, no duplicates, union = whole category, only that category, category with < 3 products, `CATEGORY_TOP_RATED_COUNT` respected, unknown category 404. Search: filter correctness and **original order preserved** |
| Unit — service | `EnquiryService` (fake provider + fake email) | success sends one email to sales inbox with product + contact details + Reply-To; unknown product 404 and **no email sent**; email failure → `EmailDeliveryError`, never success |
| Unit — adapter | `FakeStoreProductProvider` (mocked `fetch`) | mapping incl. slug/name; empty body → null; 403 + `cf-mitigated: challenge` / HTML body → Unavailable; 5xx → Unavailable; timeout → Timeout; malformed JSON / schema mismatch → BadResponse; non-numeric id → null without a call |
| Unit — adapter | `CachingProductProvider` (counting fake provider + controllable clock) | second call within 60 s → 1 upstream call; call after 60 s → refetch; rejected call not cached (next call retries); concurrent cold misses → exactly 1 upstream call, all callers get the same value; concurrent misses that fail → all reject, key cleared; `null` not cached; keys isolated (`category:a` ≠ `category:b`); size cap evicts oldest |
| Unit — adapter | `SmtpEmailProvider` (stub transport) | transport error → `EmailDeliveryError` |
| Unit — config | `env.ts` | featured IDs must be exactly 5 unique; top-rated count range; TTL ≥ 0; bad port; defaults applied |
| Integration (HTTP) | `createApp` + fakes via supertest | every endpoint's 200 shape; 400/404/413/415/429/502/504 with error body + requestId; unknown route 404; no stack traces in 500 |

### iOS (XCTest)

| Level | Target | Key cases |
|---|---|---|
| Model decoding | JSON fixtures matching §4 | all responses; `imageUrl` null/invalid → nil; `Decimal` price; error body |
| Networking | `URLSessionAPIClient` with `URLProtocol` stub | GET query encoding; POST JSON body + header; 2xx decode; 4xx/5xx → `.server` with parsed body; bad JSON → `.decoding`; `URLError` mapping; cancellation |
| Repository | `Remote*Repository` with `MockAPIClient` | correct method/path/query/body per call; result passthrough; errors propagate |
| ViewModel | Home, Category, Search, ProductDetail, Enquiry with mock repositories | loading → loaded / empty / failed; retry; category sections "Top Rated" then "All Products" in the order received, empty section omitted, both empty → empty state; search results keep received order; search empty-term guard (no request), no-results state, new search cancels old; enquiry validation messages; submit success → `onSubmitted`; failure keeps input + error; double-submit blocked; server field errors mapped |
| Validation | `EnquiryFormValidator` | mirrors backend rules |
| Navigation | `AppCoordinator` with a real `UINavigationController` | product selection pushes detail; Enquire presents modal; success shows thank-you |
| Memory | leak helper (`addTeardownBlock { XCTAssertNil(weakRef) }`) on VMs/VCs/coordinator | no retain cycles in bindings |

All iOS tests run with `URLProtocol` stubs or mock repositories, so ⌘U needs **no running backend** (D12). There is no UI test target.

### Critical end-to-end scenarios (Phase 5, executed manually + scripted where possible)

0. `docker compose up --build` from a clean clone → `GET /health` 200, Mailpit UI reachable at `:8025`.
1. App launches → Home shows featured → tap category → top rated then more → tap product → Enquire → submit valid form → Thank you → email visible in Mailpit (`http://localhost:8025`) with product and contact details.
2. Backend stopped → app shows "can't reach" error with Retry; start backend → Retry works.
3. Search with no matches → empty state; blank search → prompt, no request.
4. Invalid form → inline errors, nothing sent.
5. Mailpit stopped → submit → error shown, form data kept, no thank-you.
6. Product with missing/broken image → placeholder.

A small script can automate #1's backend half: POST an enquiry, then query Mailpit's API (`/api/v1/messages`) and assert the email exists.

---

## 9. Complete folder structure

```
kataloq/
├── README.md
├── DECISIONS.md
├── AI_USAGE.md
├── AGENTS.md
├── docker-compose.yml          # kataloq-api + mailpit (see §10)
├── .gitignore
├── docs/
│   ├── REQUIREMENTS.md
│   ├── ARCHITECTURE.md
│   └── API.md                  # contract from §4 (may stay inside ARCHITECTURE.md if short)
├── backend/                    # kataloq-api
│   ├── package.json
│   ├── package-lock.json
│   ├── tsconfig.json           # strict
│   ├── vitest.config.ts
│   ├── Dockerfile              # multi-stage, node:26-alpine (LTS), runs as non-root
│   ├── .dockerignore
│   ├── .env.example
│   ├── src/
│   │   ├── server.ts
│   │   ├── app.ts
│   │   ├── container.ts
│   │   ├── config/env.ts
│   │   ├── routes/            index.ts, products.routes.ts, categories.routes.ts, enquiries.routes.ts
│   │   ├── controllers/       products.controller.ts, categories.controller.ts, enquiries.controller.ts
│   │   ├── services/          CatalogueService.ts, EnquiryService.ts
│   │   ├── domain/            types.ts, errors.ts, ranking.ts, search.ts, enquiry.ts
│   │   ├── providers/
│   │   │   ├── product/       ProductProvider.ts, FakeStoreProductProvider.ts, fakeStoreSchemas.ts, fakeStoreMapper.ts, CachingProductProvider.ts
│   │   │   └── email/         EmailProvider.ts, SmtpEmailProvider.ts, enquiryEmailTemplate.ts
│   │   ├── middleware/        requestId.ts, requestLogger.ts, rateLimiter.ts, errorHandler.ts, notFound.ts
│   │   └── lib/logger.ts
│   └── tests/
│       ├── unit/              (mirrors src/)
│       ├── integration/       api.test.ts (+ per-route files if large)
│       └── support/           InMemoryProductProvider.ts, FakeEmailProvider.ts, fixtures.ts
└── ios/
    ├── Kataloq.xcodeproj
    ├── Kataloq/
    │   ├── App/               AppDelegate.swift, SceneDelegate.swift, AppDependencies.swift, AppConfiguration.swift
    │   ├── Coordinators/      Coordinator.swift, AppCoordinator.swift
    │   ├── Core/
    │   │   ├── Networking/    APIClient.swift, URLSessionAPIClient.swift, Endpoint.swift, APIError.swift
    │   │   ├── ImageLoading/  ImageLoader.swift
    │   │   └── Formatting/    PriceFormatter.swift
    │   ├── Models/            Product.swift, Category.swift, Enquiry.swift, APIResponses.swift
    │   ├── Repositories/      ProductRepository.swift, EnquiryRepository.swift
    │   ├── Features/
    │   │   ├── Home/          HomeViewController.swift, HomeViewModel.swift
    │   │   ├── Category/      CategoryViewController.swift, CategoryViewModel.swift
    │   │   ├── Search/        SearchViewController.swift, SearchViewModel.swift
    │   │   ├── ProductDetail/ ProductDetailViewController.swift, ProductDetailViewModel.swift
    │   │   └── Enquiry/       EnquiryViewController.swift, EnquiryViewModel.swift, EnquiryFormValidator.swift, ThankYouViewController.swift
    │   ├── UIComponents/      Theme.swift, ProductTileCell.swift, CategoryChipCell.swift, RatingView.swift, StateView.swift, FormFieldView.swift, SectionHeaderView.swift, LoadState.swift
    │   ├── Resources/         Assets.xcassets, LaunchScreen.storyboard
    │   └── Info.plist
    └── KataloqTests/
        ├── Fixtures/          *.json
        ├── Mocks/             MockAPIClient.swift, MockProductRepository.swift, MockEnquiryRepository.swift, URLProtocolStub.swift
        ├── Models/  Networking/  Repositories/  ViewModels/  Coordinators/
        └── Helpers/           XCTestCase+MemoryLeak.swift
                               # no KataloqUITests (D12)
```

Changes to the existing repo this implies:
- **Phase 3 start:** `git mv` the Xcode files into `ios/` (no content changes), add `backend/`, `docs/`, root files. Moving needs delete permission in your folder (git deletes the old paths); I'll ask once.
- **Phase 4 start:** delete `Main.storyboard`, `ViewController.swift` and the storyboard key in Info.plist; set deployment target 16.0; **remove the `KataloqUITests` folder and its target/scheme entries** from the project file (D12). Because the project uses the newer folder-based project format and I can't open Xcode, you'll confirm the project still opens and the scheme only lists `KataloqTests`.

---

## 10. Docker Compose and run model (D10)

```
docker compose up --build        # kataloq-api :3000, Mailpit SMTP :1025, Mailpit inbox http://localhost:8025
open ios/Kataloq.xcodeproj        # ⌘R on any iPhone simulator; ⌘U runs XCTest (no backend needed)
```

**`docker-compose.yml` design**

| Service | Image / build | Host ports | Config | Health |
|---|---|---|---|---|
| `mailpit` | `axllent/mailpit` (pinned version tag, chosen in Phase 3) | `8025` web inbox, `1025` SMTP | defaults; no auth (local only) | built-in |
| `kataloq-api` | `build: ./backend` | `3000` | env with defaults inline (`${VAR:-default}`), `SMTP_HOST=mailpit`, `SMTP_PORT=1025`; optional `backend/.env` override | `GET /health` |

- `kataloq-api` `depends_on: mailpit` (`condition: service_healthy`), so the first enquiry can't race Mailpit's startup.
- **No `.env` file is required** for the reviewer: every variable has a working default in Compose. `.env.example` documents them for overriding.
- Host ports are overridable (`KATALOQ_API_PORT`, `MAILPIT_UI_PORT`, `MAILPIT_SMTP_PORT`) in case 3000/8025/1025 are already taken. If you change the API port, update `API_BASE_URL` in the iOS build settings to match.
- The Simulator reaches the API at `http://localhost:3000` (the Simulator shares the Mac's network).
- Backend `Dockerfile`: multi-stage (`npm ci` + `tsc` → slim runtime with production dependencies only), `node:26-alpine` (current Active LTS, same major as the dev Mac), runs as the non-root `node` user, `CMD node dist/server.js`. The same image runs on ECS/App Runner (AWS-compatible).

**Developer mode (also documented):** `docker compose up mailpit` + `cd backend && npm ci && npm run dev` (hot reload, `SMTP_HOST=localhost`). Tests: `cd backend && npm test` (no Docker or network needed — all external calls are faked).

---

## 11. Conflicts, risks and remaining decision

### Conflicts (all resolved)

| # | Conflict | Resolution |
|---|---|---|
| C1 | Phase 3 brief "exactly five" featured vs D4 "skip unavailable" | **D13**: config enforces exactly 5; endpoint normally returns 5; a missing product is skipped + warned, never substituted. Documented exception. |
| C2 | Old REQUIREMENTS A2 / first DECISIONS draft (curated category top rated, `id` tie-break, "More in…") | Superseded by D7/D8. `docs/REQUIREMENTS.md` will carry a note pointing to the approved decisions when committed. |
| C3 | Images hosted on `fakestoreapi.com/img/…` vs "never call Fake Store from iOS" | **D14**: rule applies to product data, not static image delivery. App loads `imageUrl` directly. |
| C4 | "All Products" label excludes the top 3 | Approved as is (D8). |
| C5 | Cache (60 s) may show a just-removed featured product briefly | Accepted, documented. |
| C6 | Compose and `npm run dev` both want port 3000 | README: run one or the other; port overridable. |

### R1 — Fake Store returns a Cloudflare bot challenge (new, high impact)

**Evidence (2026-11-19, from the development Mac):** `curl -s https://fakestoreapi.com/products/categories` → `200` with data, but `curl -I https://fakestoreapi.com/products` → `403` with `cf-mitigated: challenge` (`server: cloudflare`). So Fake Store's Cloudflare protection challenges at least some non-browser requests. Whether it challenges Node's `fetch` from your network, consistently or intermittently, is **not yet known**.

**Why it matters:** if the reviewer's backend gets challenged, every product screen shows "unavailable" and the demo fails through no fault of the code.

**What we will do regardless (part of the approved design):**
- Send normal, honest request headers (`Accept: application/json`, `User-Agent: kataloq-api/<version>`).
- Detect the challenge (`403` + `cf-mitigated: challenge`, or an HTML body) → `UpstreamUnavailableError` → `502 UPSTREAM_UNAVAILABLE`, with a clear server log line: *"Fake Store returned a Cloudflare challenge; product data unavailable"*.
- The 60 s cache reduces how often we hit Fake Store.

**What we will not do:** spoof a browser, solve challenges, or use scraping/bypass services. That's evading the site operator's protection, and it's not something to defend in an interview.

**D15 (proposed) — opt-in fixture provider**

| | |
|---|---|
| What | `FixtureProductProvider implements ProductProvider`, reading a committed JSON snapshot of the Fake Store catalogue (same raw format, mapped by the same mapper as the live adapter). Selected with `PRODUCT_PROVIDER=fixture`; **default stays `fakestore`**. |
| Why | Gives the reviewer a working demo if Fake Store challenges their network, and is a concrete, testable proof that the data source is swappable by configuration alone (the brief's main point). Also makes the E2E checklist deterministic. |
| Honesty | Opt-in only, never an automatic fallback (an automatic fallback would hide an outage, contradicting "never pretend"). README states it clearly; logs show which provider is active at startup. |
| Data | You create the snapshot on your Mac with one command (`curl -s https://fakestoreapi.com/products -o backend/fixtures/fakestore-products.json`), so its origin is clear. |
| Cost | ~20–30 min including tests. |

**What I need from you:** run these on your Mac and paste the output, so we know how Node's `fetch` is treated:
```
curl -s -o /dev/null -w 'GET products: %{http_code}\n' https://fakestoreapi.com/products
node -e "fetch('https://fakestoreapi.com/products/1',{headers:{accept:'application/json','user-agent':'kataloq-api/0.1'}}).then(async r=>console.log('node fetch:',r.status,r.headers.get('cf-mitigated'),(await r.text()).slice(0,80)))"
```
Then approve or reject D15. (If Node is challenged consistently, D15 stops being optional — the live adapter would never work for us, and I'd raise that with you before building.)

---

## 12. macOS environment checklist

Verified on the development Mac (2026-11-19): Xcode 27.2 (27B52), Node v26.0.0, npm 11.12.1, npm registry reachable. **Docker not installed.**

| Tool | Required | Why this version | Install / check |
|---|---|---|---|
| macOS | A version that runs Xcode 27 | — | already satisfied |
| Xcode | **27.x** (27.2 verified) | Xcode 27 accepts iOS deployment targets 15–27, so our **iOS 16.0** target builds | `xcodebuild -version` |
| iOS Simulator runtime | iOS 27 runtime + any iPhone simulator | Run target | Xcode → Settings → Components; `xcrun simctl list devices available` |
| Node.js | **26.x LTS** (Active LTS since 28 Oct 2026); `engines: ">=24"` so Node 24 LTS also works | Matches the Docker image (`node:26-alpine`). You have 26.0.0 (released while 26 was "Current"); updating to the latest 26.x patch is recommended but not required | `node -v`; update via nodejs.org installer, `brew upgrade node`, or nvm `nvm install 26` |
| npm | **11.x** (bundled with Node 26) | Lockfile v3, `npm ci` | `npm -v`, `npm ping` |
| Docker Engine + **Compose v2** (`docker compose`, not `docker-compose`) | Any current version with Compose v2 | Runs `kataloq-api` + Mailpit | Options below; check `docker --version && docker compose version && docker run --rm hello-world` |
| Git | Any recent (ships with Xcode CLT) | Feature branch + PR | `git --version` |
| GitHub CLI | Any recent, authenticated | Create repo + open PR in Phase 7 | `brew install gh`, `gh auth login`, `gh auth status` |
| Free ports | 3000 (API), 8025 (Mailpit UI), 1025 (SMTP) | Compose port mapping | `lsof -nP -iTCP:3000,8025,1025 -sTCP:LISTEN` (no output = free) |

**Docker options (pick one):**
- **Docker Desktop** — simplest; includes Compose v2. Free for personal use and small businesses; larger organisations need a paid subscription (check Docker's current terms). Fine on your own Mac.
- **Colima** (free, open source): `brew install colima docker docker-compose`, then `colima start`. Compose v2 needs the plugin path set (`~/.docker/config.json` → `"cliPluginsExtraDirs": ["/opt/homebrew/lib/docker/cli-plugins"]`).
- **OrbStack** — fast, Compose included; free for personal use, paid for commercial use.

Because the reviewer may not be able to use Docker Desktop for licensing reasons, the README will also document a **no-Docker path**: `brew install mailpit && mailpit` (SMTP :1025, UI :8025) plus `cd backend && npm ci && npm run dev`.

**Reviewer prerequisites (for the README):** Xcode 27+, Docker with Compose v2 (or Mailpit via Homebrew + Node 24+ for the no-Docker path). No accounts or API keys.
