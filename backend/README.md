# kataloq-api

REST API for **Kataloq – Product Catalogue Platform**. Serves product data to the Kataloq iOS app and sends product enquiries to the sales inbox.

- Product data comes from [Fake Store API](https://fakestoreapi.com) through a replaceable `ProductProvider`. **The iOS app never calls Fake Store directly**; it only gets product image URLs, which it loads from the image host.
- Enquiry emails go through a replaceable `EmailProvider` (SMTP). Locally they are captured by [Mailpit](https://mailpit.axllent.org) so you can read them in a browser. No accounts or API keys are needed.

Node.js 26 LTS (24+ works) · TypeScript 7 (strict) · Express 5 · zod 4 · nodemailer · vitest + supertest.

---

## Run it

### Option 1: Docker Compose (recommended, one command)

From the **repository root**:

```bash
docker compose up --build
```

| Service | URL |
|---|---|
| kataloq-api | http://localhost:3000 (health: http://localhost:3000/health) |
| Mailpit inbox | http://localhost:8025 |

Stop with `Ctrl-C`, clean up with `docker compose down`.

### Option 2: Node directly (for development)

```bash
# 1. Mailpit, for enquiry emails (either one)
docker compose up mailpit                 # from the repo root
# or, without Docker:  brew install mailpit && mailpit

# 2. The API, with auto-reload
cd backend
npm ci
npm run dev                               # http://localhost:3000
```

Don't run options 1 and 2 at the same time: both use port 3000.

---

## Configuration

All configuration is via environment variables, **all optional**. Defaults work out of the box. They are documented in [`.env.example`](.env.example). For `npm run dev`, copy it to `.env` and edit. For Compose, export the variable or put it in a `.env` file at the repository root.

Configuration is validated at startup; an invalid value stops the server with a clear message, for example:

```
Invalid configuration:
  - FEATURED_PRODUCT_IDS: must contain exactly 5 comma-separated product IDs
```

Key settings:

| Variable | Default | Meaning |
|---|---|---|
| `FEATURED_PRODUCT_IDS` | `1,5,9,14,18` | The 5 Home products, in order (covers all 4 categories) |
| `CATEGORY_TOP_RATED_COUNT` | `3` | Size of a category's "Top Rated" section |
| `PRODUCT_CACHE_TTL_SECONDS` | `60` | In-memory product cache; `0` disables it |
| `UPSTREAM_TIMEOUT_MS` | `5000` | Timeout for Fake Store requests |
| `SMTP_HOST` / `SMTP_PORT` | `localhost` / `1025` | Mailpit (`mailpit` inside Compose) |
| `SALES_INBOX_EMAIL` | `sales@kataloq.local` | Where enquiries are sent |
| `ENQUIRY_RATE_LIMIT_PER_MINUTE` | `5` | Per client IP |

Secrets (`SMTP_USER`, `SMTP_PASS`) are only needed for a real SMTP relay and must never be committed.

---

## API

Base URL `http://localhost:3000/api/v1`. JSON in and out. Every response has an `X-Request-Id` header.

| Method | Path | Success |
|---|---|---|
| GET | `/health` *(no prefix)* | `200 {"status":"ok"}` |
| GET | `/products/featured` | `200 {"products": Product[]}` |
| GET | `/categories` | `200 {"categories": Category[]}` |
| GET | `/categories/:categoryId/products` | `200 {"category", "topRated": Product[], "additional": Product[]}` |
| GET | `/products/search?q=term` | `200 {"query", "products": Product[]}` |
| GET | `/products/:productId` | `200 {"product": Product}` |
| POST | `/enquiries` | `202 {"enquiryId", "status": "sent"}` |

```jsonc
// Product
{
  "id": "1",
  "title": "Fjallraven - Foldsack No. 1 Backpack, Fits 15 Laptops",
  "description": "Your perfect pack for everyday use…",
  "price": { "amount": 109.95, "currency": "USD" },
  "category": { "id": "mens-clothing", "name": "Men's Clothing" },
  "imageUrl": "https://fakestoreapi.com/img/81fPKd-2AYL._AC_SL1500_t.png",   // or null
  "rating": { "average": 3.9, "count": 120 }
}
```

### Business rules

- **Featured:** the 5 configured IDs, in configured order. A configured product that no longer exists is skipped and logged (never replaced), so the list can temporarily be shorter.
- **Category:** all products in the category sorted by rating average (desc), then rating count (desc); ties keep Fake Store's order. The first 3 are `topRated` ("Top Rated" in the app), the rest are `additional` ("All Products"). No product appears in both.
- **Search:** case-insensitive substring match of the whole trimmed term against title, description and category name. Results keep Fake Store's order (no relevance ranking). 1–100 characters.
- **Enquiry:** `name` and `email` required; `phone` and `message` optional. Backend validation is authoritative. `202` is returned **only after** the email provider accepted the message.

### Errors

Every error has the same shape:

```json
{ "error": { "code": "VALIDATION_ERROR", "message": "Some fields are invalid.", "requestId": "…",
             "details": [{ "field": "email", "message": "Enter a valid email address." }] } }
```

| Status | `code` | When |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Invalid path/query/body (`details` lists the fields), malformed JSON |
| 404 | `PRODUCT_NOT_FOUND`, `CATEGORY_NOT_FOUND`, `ROUTE_NOT_FOUND` | Unknown product, category or URL |
| 413 | `PAYLOAD_TOO_LARGE` | Body over 10 KB |
| 415 | `UNSUPPORTED_MEDIA_TYPE` | Enquiry body not JSON |
| 429 | `RATE_LIMITED` | Too many enquiries (see `Retry-After`) |
| 502 | `UPSTREAM_UNAVAILABLE`, `UPSTREAM_BAD_RESPONSE` | Fake Store down, erroring, challenging the request, or returning garbage |
| 502 | `EMAIL_DELIVERY_FAILED` | The email provider did not accept the enquiry |
| 504 | `UPSTREAM_TIMEOUT` | Fake Store slower than `UPSTREAM_TIMEOUT_MS` |
| 500 | `INTERNAL_ERROR` | Anything unexpected (details are logged, never returned) |

### Examples

```bash
curl -s localhost:3000/api/v1/products/featured
curl -s localhost:3000/api/v1/categories
curl -s localhost:3000/api/v1/categories/electronics/products
curl -s "localhost:3000/api/v1/products/search?q=jacket"
curl -s localhost:3000/api/v1/products/1

curl -s -X POST localhost:3000/api/v1/enquiries \
  -H 'Content-Type: application/json' \
  -d '{"productId":"1","name":"Jane Citizen","email":"jane@example.com","phone":"+61 400 000 000","message":"Is this available in blue?"}'
# → 202 {"enquiryId":"…","status":"sent"}; the email is now visible at http://localhost:8025
```

---

## Tests

```bash
npm test            # unit + integration (vitest)
npm run typecheck   # tsc --noEmit, strict
npm run build       # compile to dist/
```

No network, Docker or Mailpit needed: Fake Store's `fetch`, the SMTP transport and the clock are faked.

- `tests/unit`: config validation, Fake Store adapter (incl. timeout, Cloudflare challenge, empty-body "not found"), cache (TTL, single-flight, failures not cached), ranking, search, enquiry validation, email content, services, logger.
- `tests/integration`: the real Express app over HTTP (supertest) with in-memory fakes: every endpoint, every error status, rate limiting, request IDs, and checks that no personal data reaches the logs.

---

## Code map

```
src/
  server.ts          process entry: config → container → listen; shutdown & crash handling
  container.ts       composition root: the ONLY place that picks concrete adapters
  app.ts             createApp(deps): Express app from injected services
  config/env.ts      env vars → validated, typed AppConfig
  routes/ controllers/ http/ middleware/   HTTP concerns only
  services/          CatalogueService, EnquiryService (business rules)
  domain/            types (= API contract), errors, ranking, search, enquiry validation
  providers/product/ ProductProvider interface, Fake Store adapter, caching decorator
  providers/email/   EmailProvider interface, SMTP adapter, email template
```

**Replacing the product data source:** implement `ProductProvider` (4 methods) and change `container.ts`. **Replacing the email vendor:** implement `EmailProvider` (1 method), e.g. AWS SES, and change `container.ts`. Services, routes, the API contract and the iOS app stay unchanged.
