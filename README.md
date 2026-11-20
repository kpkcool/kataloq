# Kataloq – Product Catalogue Platform

A product catalogue proof of concept: a **native iOS app (Swift, UIKit, MVVM-C)** backed by a **Node.js + TypeScript REST API** that sources product data from [Fake Store API](https://fakestoreapi.com) and emails product enquiries to a sales inbox.

| Customers can… | Where |
|---|---|
| See 5 hand-picked featured products, then all products | Home ("Featured" row, then an "All Products" grid) |
| Browse a category: its 3 top-rated products, then all the others | Home → category chip |
| Search by text (title, description, category) | Home → search bar (results update as you type, or tap Search on the keyboard) |
| See a product's details | Tap any product |
| Send an enquiry and get a thank-you confirmation | Product → "Enquire about this product" |

**The iOS app never calls Fake Store for product data.** It only talks to `kataloq-api`, which owns the business rules and maps Fake Store into Kataloq's own API contract. Product images are static files the app loads from the URL the backend returns.

---

## Quick start (about 5 minutes)

**Prerequisites:** macOS with **Xcode 27+** (iOS Simulator runtime installed) and **Docker** with Compose v2 (Docker Desktop, OrbStack or Colima). No accounts or API keys.

```bash
git clone https://github.com/kpkcool/kataloq.git
cd kataloq
docker compose up --build -d       # kataloq-api on :3000, Mailpit inbox on :8025
open ios/Kataloq.xcodeproj         # pick any iPhone simulator, press ⌘R
```

- App: browse, search, open a product, tap **Enquire about this product**, send the form.
- **See the enquiry email:** open **http://localhost:8025** (Mailpit's web inbox).
- Stop everything: `docker compose down`.

Ports already in use? `KATALOQ_API_PORT=3100 MAILPIT_UI_PORT=8125 docker compose up --build -d`, and set `API_BASE_URL` to `http://localhost:3100` in the Kataloq target's build settings.

**No Docker?** `brew install mailpit && mailpit` in one terminal, then `cd backend && npm ci && npm run dev` (Node 24+) in another.

---

## Architecture

```
┌──────────────────────┐   REST/JSON /api/v1   ┌─────────────────────────────────────────────┐
│ Kataloq iOS (UIKit)  │ ────────────────────▶ │ kataloq-api (Node 26 + TypeScript, Express)  │
│ ViewController       │                       │ routes → controllers → services → domain     │
│   ↕ ViewModel        │                       │                 │                 │          │
│ Coordinator          │                       │        ProductProvider      EmailProvider    │
│ Repository→APIClient │                       │   (60 s cache decorator)          │          │
└──────────┬───────────┘                       │   FakeStoreProductProvider  SmtpEmailProvider│
           │ image bytes only                  └──────────────┼────────────────────┼─────────┘
           ▼                                                  ▼                    ▼
    image host (imageUrl)                              fakestoreapi.com      Mailpit (SMTP/UI)
```

- **Backend:** layered; services depend only on the `ProductProvider` and `EmailProvider` interfaces. Swapping the data source or email vendor means writing one adapter and changing `backend/src/container.ts`. Details: [`backend/README.md`](backend/README.md).
- **iOS:** MVVM-C. ViewModels (no UIKit) own state and intents; ViewControllers render; one `AppCoordinator` does all navigation; repositories sit behind protocols and are injected through a plain `AppDependencies` struct.
- Full design, API contract and data models: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md). Decisions and trade-offs: [`DECISIONS.md`](DECISIONS.md).

## Technology

| | |
|---|---|
| iOS | Swift, UIKit (programmatic, compositional layout + diffable data sources), MVVM-C, URLSession + async/await, Codable, XCTest. iOS 16+, iPhone. No third-party dependencies. |
| Backend | Node.js 26 LTS, TypeScript 7 (strict), Express 5, zod 4, nodemailer, express-rate-limit; vitest + supertest |
| Local infrastructure | Docker Compose: `kataloq-api` + Mailpit. The backend image runs unchanged on AWS (ECS / App Runner). |

**Why this combination**
- **Client: iOS app in Swift (UIKit).** Native iOS is my strongest platform, so I can own and defend every line. UIKit with MVVM-C keeps logic in testable ViewModels and navigation in one coordinator, so screens can be restyled when the creative work lands without touching business logic.
- **Backend: Node.js with TypeScript.** Strict TypeScript catches API-contract mistakes at compile time, and Node is the quickest path in the brief to a tested REST API that runs anywhere on AWS. The backend owns all product data (the app never calls Fake Store) and hides the data source and email provider behind interfaces, so both can be replaced.

More detail and the trade-offs: [`DECISIONS.md`](DECISIONS.md) §1.

## Repository structure

```
kataloq/
├── README.md, DECISIONS.md, AI_USAGE.md, AGENTS.md
├── docker-compose.yml        kataloq-api + Mailpit
├── scripts/verify.sh         runs every check (tests, Compose, end-to-end smoke)
├── docs/                     REQUIREMENTS, ARCHITECTURE, TESTING, CODE_REVIEW, SUBMISSION
├── backend/                  kataloq-api (see backend/README.md)
│   ├── src/                  config, routes, controllers, services, domain, providers, middleware
│   └── tests/                unit/ and integration/
└── ios/
    ├── Kataloq.xcodeproj
    ├── Kataloq/              App, Coordinators, Core (Networking, ImageLoading, Formatting),
    │                         Models, Repositories, Features (Home, Category, Search,
    │                         ProductDetail, Enquiry), UIComponents
    └── KataloqTests/         XCTest: models, networking, repositories, ViewModels, coordinator
```

## Configuration

- **Backend:** environment variables, all optional with working defaults, documented in [`backend/.env.example`](backend/.env.example). Featured products: `FEATURED_PRODUCT_IDS` (exactly 5). Category "Top Rated" size: `CATEGORY_TOP_RATED_COUNT`. Invalid config stops the server at startup with a clear message. No secrets are committed.
- **iOS:** backend URL from the `API_BASE_URL` build setting (default `http://localhost:3000`), overridable at run time with the `KATALOQ_API_BASE_URL` environment variable (Scheme → Run → Arguments). For a **physical device**, set it to your Mac's LAN address, e.g. `http://192.168.1.20:3000`.

## API

| Method | Path | Returns |
|---|---|---|
| GET | `/health` | `{"status":"ok"}` |
| GET | `/api/v1/products` | all products (Home "All Products") |
| GET | `/api/v1/products/featured` | 5 configured products |
| GET | `/api/v1/categories` | categories |
| GET | `/api/v1/categories/:categoryId/products` | `{category, topRated[3], additional[]}` |
| GET | `/api/v1/products/search?q=` | matching products |
| GET | `/api/v1/products/:productId` | one product |
| POST | `/api/v1/enquiries` | `202 {enquiryId, status:"sent"}` once the email is accepted |

Errors always look like `{"error":{"code","message","requestId","details?"}}`. Full contract and curl examples: [`backend/README.md`](backend/README.md).

## Tests

```bash
cd backend && npm test               # backend unit + integration (no network or Docker needed)
cd backend && npm run typecheck
# iOS: open ios/Kataloq.xcodeproj and press ⌘U, or:
xcodebuild test -project ios/Kataloq.xcodeproj -scheme Kataloq \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -parallel-testing-enabled NO

./scripts/verify.sh                  # everything + end-to-end smoke test against Compose
```

All unit tests use fakes (no backend, network or Mailpit needed). The iOS suite runs serially (`-parallel-testing-enabled NO`): it finishes in under a second, and parallel Simulator clones occasionally fail to start, which makes `xcodebuild` report TEST FAILED without any failing test. What's covered and the recorded results: [`docs/TESTING.md`](docs/TESTING.md).

## Known limitations

- Depends on the public Fake Store API: if it's down or challenges your network (Cloudflare), product screens show a "temporarily unavailable" error (the backend surfaces this, it doesn't bypass it).
- Enquiries aren't stored; the email is the record. If email fails the user is told and can retry; nothing is queued.
- Rate limiting and the product cache are in memory (per instance).
- Search is substring matching with no relevance ranking; no pagination (Fake Store has ~20 products).
- iPhone only, portrait. No UI/snapshot tests for screens (ViewModels and navigation are tested).
- Prices are shown in USD (Fake Store has no currency).

More, with reasons and what I'd do next: [`DECISIONS.md`](DECISIONS.md). How AI was used: [`AI_USAGE.md`](AI_USAGE.md).
