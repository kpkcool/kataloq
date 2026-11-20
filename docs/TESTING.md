# Kataloq – Testing and Acceptance (Phase 5)

This file records **only results that were actually observed**. Anything not yet run is marked *Pending* and must be filled from a real run of `./scripts/verify.sh` and the manual iOS checklist below. Do not edit a *Pending* row to PASS without running it.

## How to run everything

```bash
./scripts/verify.sh                         # backend tests, Compose, E2E smoke, iOS XCTest
SIMULATOR="iPhone 17" ./scripts/verify.sh   # if "iPhone 18 Pro" isn't installed
```

It prints a summary table: paste it into "Latest full run" below.

## Automated test suites

| Suite | What it covers | Runs without network/Docker |
|---|---|---|
| Backend unit (`backend/tests/unit`) | Config validation; Fake Store adapter (mapping, empty-body "not found", 403 Cloudflare challenge, 5xx, timeout, bad JSON); cache (TTL, single-flight, failures and `null` not cached, eviction); ranking; search; enquiry validation; email template; SMTP adapter; services; logger | Yes |
| Backend integration (`backend/tests/integration`) | Real Express app over HTTP (supertest) with in-memory fakes: every endpoint, 400/404/413/415/429/500/502/504, request IDs, no PII or query strings in logs | Yes |
| iOS XCTest (`ios/KataloqTests`) | Model decoding; `URLSessionAPIClient` via `URLProtocol` stub; repositories; Home/Category/Search/ProductDetail/Enquiry ViewModels (states, retry, cancellation, validation, success/failure); form validator; coordinator navigation; formatting; configuration; memory-leak checks | Yes |
| E2E smoke (`scripts/verify.sh` §3) | Live backend in Compose → live Fake Store and Mailpit: all five acceptance criteria, email captured, email-provider outage | No (needs Docker + internet) |

## Results observed so far (from the developer's Mac)

| When (IST, 2026-11-19) | Check | Result | Evidence |
|---|---|---|---|
| 17:45 | Backend increment 1: `npm run typecheck && npm test` | **PASS**: typecheck clean, 71/71 tests (vitest 5.1.1) | Terminal output pasted in session |
| 18:01 | Backend increment 2 | **PASS**: typecheck clean, 107/107 | Terminal output |
| 18:10 | Backend increment 3: typecheck, tests, `npm run build` | **PASS**: 137/137, build OK | Terminal output |
| 18:12 | Live API via `npm run dev` against Fake Store | **PASS**: featured = 1, 5, 9, 14, 18 (all 4 categories); electronics top = 12, 11, 9, rest = 10, 13, 14 (rating then count); search `jacket` matched; `/products/999` → 404 with request ID; cached repeat calls ≈0.3 ms | curl output + server log |
| 18:25 | Live enquiry with Mailpit (`docker run`) | **PASS**: 202 `{"enquiryId",…,"status":"sent"}`; with Mailpit stopped → 502 `EMAIL_DELIVERY_FAILED` in 2.8 ms | curl output + server log |
| 22:24 | iOS app on iPhone 18 Pro Simulator against local backend | **PASS (manual)**: Home showed categories and featured products with images, prices, ratings. Also revealed the featured-grid overflow bug (fixed in the next step). | Screenshot |

| 2026-11-20 06:45 | `./scripts/verify.sh` (first full run) | Backend typecheck / tests / build **PASS**. iOS **built** (incl. Enquiry) and ran **100 tests, 1 failure**: `RemoteEnquiryRepositoryTests.testSubmitPostsTheEnquiryAsJSON` compared JSON bytes, but `JSONEncoder` key order isn't stable (both bodies 81 bytes). Test bug, fixed to compare parsed JSON. `docker compose up` **FAIL** (port 3000 most likely held by a running `npm run dev`), so every E2E row was not executed (`000`). | Script summary pasted in session |
| 2026-11-20 07:20 | App: enquiry with the mail server down | **PASS (M8)**: API 502 in 8.6 ms; app showed "We could not send your enquiry right now…", kept name/email, no Thank you | Screenshot + server log |
| 2026-11-20 07:23 | App: enquiry with Mailpit running | **PASS (M6, M7)**: Thank you screen (product + reply email + reference); Mailpit received "New enquiry: Fjallraven - Foldsack No. 1 Backpack…" to `sales@kataloq.local`, Reply-To the customer, product and customer details, "(not provided)" for phone/message | Screenshots of app and Mailpit |
| 2026-11-20 07:25 | App: Electronics category | **PASS (M2 / AC2 in app)**: Top Rated 12 (4.8/400), 11 (4.8/319), 9; All Products 10 (2.9/470), 13 (2.9/250), 14 (2.2/140); no repeats | Screenshots |
| 2026-11-20 07:25 | App: Home (carousel version) | **PASS (M1)**: chips with icons, Featured carousel 1, 5, … | Screenshot. Visual issues found: gap between title and price on cards; stretched check icon on Thank you; empty space below Featured. Fixed in the next change. |
| 2026-11-20 08:12–08:20 | App: Home after the product card design system | **PASS (M1 / AC1 in app)**: Featured 1, 5, 9… as white bordered cards with soft shadow, square aspect-fit images, two-line titles, aligned prices and ratings; All Products grid. Found: search bar rendered at the **bottom** (iOS 26 toolbar placement) and the gap above All Products **changed while scrolling** Featured. Both fixed (pinned search bar; card height estimate computed from tokens). | Screenshots |
| 2026-11-20 08:23–08:27 | App: Enquiry sheet | Layout checked: close button moved to the right, Send button pinned at the bottom, Message box fills spare height, red `*` on required / grey "(optional)" | Screenshots |
| 2026-11-20 08:37 | `docker compose up --build` | **FAIL**: `kataloq-api` restart loop, `Cannot read package config /app/package.json: permission denied`. Files on the Mac were mode 600 and the image runs as user `node`. Fixed: Dockerfile copies runtime files `--chown=node:node`. | Compose log |
| 2026-11-20 08:39 | App: enquiry against the API **in Docker** | **PASS (M6)**: API log `POST /api/v1/enquiries 202` from `kataloq-api-1`; Thank you screen with product, reply email and reference `AE413833` | Screenshot + container log |
| 2026-11-20 12:26 | iOS XCTest (parallel, Xcode default) | `TEST FAILED` with 0 failing tests: only 74 of 123 ran (a parallel Simulator clone stopped) | Terminal output |
| 2026-11-20 12:29 | iOS XCTest, `-parallel-testing-enabled NO` | **PASS: 123/123** | Terminal output |
| 2026-11-20 12:31 | `./scripts/verify.sh` (app also running from Xcode on the same Simulator) | iOS **FAIL**: 75 of 123, `HomeViewModelTests.testBackendNotRunningShowsConnectionMessage` and `testNothingToShowIsEmptyState` **crashed**. Cause: test bug, a data race in `MockProductRepository` (Home calls three repository methods concurrently with `async let`; the mock appended to an unguarded array). Fixed with a lock in the mocks. | `/tmp/kataloq-xcodebuild.log` |
| 2026-11-20 12:35 | `./scripts/verify.sh` | **ALL PASS**, see below | Script summary |

**Not yet observed** (no output seen in the session):
- Search as you type in the Simulator (M10).
- Product detail screen checked on its own (M3); it was reached on the way to Enquire.
- Backend-down state in the app (M11), larger text and VoiceOver (M13), small iPhone vs Pro Max.

## Latest full run (`scripts/verify.sh`)

Run on 2026-11-20 at 12:35 IST, developer's Mac (Xcode 27.2, iPhone 18 Pro Simulator, Docker 29.9.3, Node 26):

```
backend typecheck                                PASS
backend tests (vitest)                           PASS  Tests  204 passed (204)
backend build                                    PASS
docker compose up --build                        PASS
GET /health                                      PASS
compose service health                           INFO  kataloq-api=starting mailpit=healthy
AC1 featured = 5 configured products             PASS  1:mens-clothing 5:jewelery 9:electronics 14:electronics 18:womens-clothing
categories                                       PASS  electronics jewelery mens-clothing womens-clothing
AC2 category: top 3 by rating, rest, no dupes    PASS  top=12,11,9 rest=10,13,14
AC3 search 'JACKET' only matching, case-insens.  PASS  3,15,16,17
search with no matches -> empty list             PASS
blank search -> 400                              PASS
AC4 product details                              PASS  Fjallraven - Foldsack No. 1 Backpack, Fits 15 Laptops | 109.95 | Men's Clothing | 3.9
unknown product -> 404                           PASS
invalid enquiry -> 400                           PASS
AC5 enquiry accepted (202)                       PASS  {"enquiryId":"e57e9181-…","status":"sent"}
AC5 email captured in Mailpit                    PASS  1 email(s): New enquiry: John Hardy Women's Legends Naga … -> sales@kataloq.local
email provider down -> 502, never 202            PASS
iOS XCTest                                       PASS  Executed 123 tests, with 0 failures (0 unexpected) in 0.334 (0.377) seconds
```

"compose service health: starting" is the Docker health check's first interval; `GET /health` had already answered.

## Acceptance criteria (assignment)

| # | Requirement | Expected behaviour | Actual result | Status |
|---|---|---|---|---|
| AC1 | Home: 5 chosen top-rated products | Exactly the 5 configured products, in order, each with image, title, price, rating | API: 1, 5, 9, 14, 18 (verify.sh, 20 Nov 12:35). App: Featured carousel 1, 5, 9… (20 Nov 08:20) | **PASS** |
| AC2 | Category: top-rated products for that category, then additional products | Tap category → "Top Rated" (3, by rating then count) then "All Products" (rest), no duplicates, only that category | API (19 Nov 18:12) and app (20 Nov 07:25): electronics 12, 11, 9 / 10, 13, 14 | **PASS** |
| AC3 | Search: only products matching the term | Search on Home: typing (after a 300 ms pause) or the keyboard Search button → only matches (title, description, category; case-insensitive); empty → back to Home; none → "No products match" | API: `JACKET` → 3, 15, 16, 17; no match → empty; blank → 400 (verify.sh, 20 Nov 12:35). iOS: `SearchViewModelTests` (typing, fast typing sends only the last term, clearing) | API + unit **PASS**; app *Pending (M10)* |
| AC4 | Product page | Tapping any tile shows image, name, description, price, category, rating, Enquire | API: product 1 with title, price, category, rating; unknown → 404 (verify.sh, 20 Nov 12:35). App: detail → Enquire reached (20 Nov 08:23) | API **PASS**; app screen *Pending visual check (M3)* |
| AC5 | Enquiry → email to sales inbox → thank you | Valid form → 202 → email in Mailpit → "Thank you" screen; failure → error, data kept, retry | API: 202, email in Mailpit, 502 on outage (verify.sh, 20 Nov 12:35). App: failure and success paths, email in Mailpit (07:20–07:23); success against the Docker API (08:39) | **PASS** |

## Manual iOS end-to-end checklist

Run with `docker compose up -d` and the app on a Simulator (⌘R). Record PASS/FAIL and notes.

| # | Step | Expected | Result |
|---|---|---|---|
| M1 | Launch app | Home: search bar under the title, category chips with icons, "Featured" row of 5 cards, "All Products" grid | **PASS** (20 Nov 08:20) |
| M2 | Tap "Electronics" | "Top Rated" row (3) then "All Products" grid (3), no repeats | **PASS** (20 Nov 07:25, before the card redesign) |
| M3 | Tap a product | Detail: image, category, title, price, rating, description, sticky "Enquire about this product" | *Pending* |
| M4 | Tap Enquire, tap "Send enquiry" with empty form | Inline errors on Name and Email; nothing sent | *Pending* |
| M5 | Enter `J` / `nope` as name/email, send | Inline length/format errors | *Pending* |
| M6 | Valid name + email (phone/message optional), send | Button shows "Sending…", then "Thank you!" screen naming the product and email | **PASS** (20 Nov 07:23 and 08:39) |
| M7 | Open http://localhost:8025 | One new email to `sales@kataloq.local` with product and customer details | **PASS** (20 Nov 07:23) |
| M8 | `docker compose stop mailpit`, send another enquiry | Red error "We could not send your enquiry right now…", form keeps input, no Thank you | **PASS** (20 Nov 07:20) |
| M9 | `docker compose start mailpit`, tap "Send enquiry" again | Thank you screen | **PASS** (20 Nov 07:23) |
| M10 | Type `jacket`, then `SSD`, then `unicorn` in the Home search bar, then clear it | Results update while typing / case-insensitive matches / "No products match" / back to Home without a request | *Pending* |
| M11 | `docker compose stop kataloq-api`, pull to refresh on Home | "Can't reach Kataloq right now…" + "Try again"; start API → Try again works | *Pending* |
| M12 | A product with no/failed image | Grey photo placeholder, no crash | *Pending* (covered by unit test for `imageUrl: null`) |
| M13 | Settings → Accessibility → Larger Text, VoiceOver on Home | Text scales; tiles read "title, price, Rated x out of 5 from n reviews" | *Pending* |

## Known gaps in automated coverage

- No UI/snapshot tests for ViewControllers (see `docs/CODE_REVIEW.md` R2).
- No automated test drives the Simulator against the live backend; that path is the manual checklist above plus `verify.sh` §3 for the API.
- iOS tests run serially (`-parallel-testing-enabled NO`). The suite takes about 0.3 s; parallel Simulator clones made `xcodebuild` report TEST FAILED without a failing test (20 Nov 12:26).
