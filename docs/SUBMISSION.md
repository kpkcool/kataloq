# Kataloq – Pull request description and submission summary

## Pull request (feature/kataloq-mvp → main)

**Title:** Kataloq – Product Catalogue Platform (UIKit iOS app + Node.js/TypeScript API)

> Copy everything between the lines into the PR body (`gh pr create --body-file` reads the whole file, so paste this section instead if you use the web UI).

---

## Summary

Kataloq is a product catalogue proof of concept built as a foundation that can grow, not a throwaway prototype. It is a **native iOS app (Swift, UIKit, MVVM-C)** backed by a **Node.js + TypeScript REST API**. The API is the only component that talks to the product data source (Fake Store) and to the email provider. All five acceptance criteria pass end to end, with 204 backend tests and 123 iOS tests.

## The problem

An entrepreneur wants an interactive proof of concept of their product catalogue that they can firm up the vision with, and that won't be thrown away. The product data source, the look and feel and the email provider are all expected to change. Customers must be able to:

1. see 5 hand-picked "top rated" products on Home;
2. open a category and see its top-rated products, then the rest;
3. search by text and see only matching products;
4. open a product's details;
5. send an enquiry, so the sales inbox gets an email and the customer sees "Thank you".

## Run it locally (about 5 minutes)

**You need:** macOS with **Xcode 27+** and an iOS Simulator, and **Docker** with Compose. No accounts, API keys or `.env` file: every setting has a working default (`backend/.env.example`).

```bash
git clone https://github.com/kpkcool/kataloq.git && cd kataloq
docker compose up --build -d      # API on http://localhost:3000, Mailpit inbox on http://localhost:8025
open ios/Kataloq.xcodeproj        # choose an iPhone simulator, press ⌘R
```

**Try each acceptance criterion in the app:**

| # | Do this | You should see |
|---|---|---|
| 1 | Launch the app | Home: search bar, category chips, a **Featured** row of the 5 configured products, then **All Products** |
| 2 | Tap **Electronics** | **Top Rated** (3, highest rated first), then **All Products** (the rest), no repeats |
| 3 | Type `jacket` in the search bar (or tap Search on the keyboard) | Only products whose title, description or category contains "jacket" |
| 4 | Tap any product | Details: image, category, title, price, rating, description, **Enquire** button |
| 5 | Tap **Enquire**, enter a name and email, tap **Send enquiry** | "Thank you!" with a reference, and the email at **http://localhost:8025** |

Stop everything with `docker compose down`. Ports busy? `KATALOQ_API_PORT=3100 MAILPIT_UI_PORT=8125 docker compose up --build -d` (see the README to point the app at the new port).

**Run the tests:**
```bash
./scripts/verify.sh               # everything: backend tests, Docker Compose, end-to-end checks of all 5 criteria, iOS tests
```
Or separately:
```bash
cd backend && npm ci && npm run typecheck && npm test      # backend unit + integration (no network needed)
xcodebuild test -project ios/Kataloq.xcodeproj -scheme Kataloq \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -parallel-testing-enabled NO    # iOS (or ⌘U in Xcode)
```
Different simulator installed? `SIMULATOR="iPhone 17" ./scripts/verify.sh`.

## What was built

| Acceptance criterion | How it works |
|---|---|
| **Home: 5 chosen products** | `FEATURED_PRODUCT_IDS` (exactly 5, validated at startup) → `GET /api/v1/products/featured`. A missing product is skipped and logged, never silently replaced. Home also shows an "All Products" grid (`GET /api/v1/products`). |
| **Category: top rated, then the rest** | `GET /api/v1/categories/:id/products`. The backend ranks by rating score, then number of ratings; the first 3 are "Top Rated", the rest "All Products", with no duplicates. |
| **Search: only matches** | Search bar on Home. Results appear as you type (after a 300 ms pause, older requests cancelled) and immediately on the keyboard's Search button. The backend does a case-insensitive match on title, description and category. Blank or over-long terms are never sent. |
| **Product page** | Tapping any product card opens the details screen with a sticky **Enquire** button. |
| **Enquiry → email → thank you** | Form with name and email required (red `*`), phone and message optional; validated in the app and, authoritatively, on the backend. `POST /api/v1/enquiries` returns `202` **only after the email server accepts the email**, then the app shows "Thank you". If sending fails, the user sees an error, keeps their input and can retry. |

Every screen has loading, empty and error-with-retry states. Text supports Dynamic Type, and the main elements have VoiceOver labels.

## How it's built, and how it grows

```
iOS app (UIKit, MVVM-C) ──REST /api/v1──▶ kataloq-api (Node + TypeScript)
                                           routes → controllers → services
                                                 │                 │
                                          ProductProvider     EmailProvider
                                          (Fake Store today)  (SMTP / Mailpit today)
```

- **Replaceable data source and email provider.** Services depend only on the `ProductProvider` and `EmailProvider` interfaces. Moving to a real catalogue or to SES means one new adapter, wired in `backend/src/container.ts`; the app and the business rules don't change.
- **The app never calls Fake Store.** The backend maps Fake Store into Kataloq's own API contract, so the app is unaffected by a data-source change. Images load from the URL the backend returns.
- **Look and feel can change safely.** ViewModels hold the logic with no UIKit and are unit tested; ViewControllers only render; one coordinator owns navigation. Product cards are one reusable component driven by design tokens in `Theme`.
- **Backend basics:** strict TypeScript, zod validation on every input, one error handler with a consistent error format, request IDs, JSON logs without personal data, a 60-second product cache, and rate limiting on enquiries.
- **AWS-ready:** the API is a plain Docker image (ECS / App Runner); configuration comes only from environment variables.

## Testing

Full `./scripts/verify.sh` run on 2026-11-20 (Xcode 27.2, iPhone 18 Pro Simulator, Docker 29.9.3, Node 26): **all PASS**.

- **Backend:** typecheck clean, **204/204** tests (unit + HTTP-level integration), build OK.
- **iOS:** **123 tests, 0 failures**: ViewModels (states, retry, cancellation, validation), networking via `URLProtocol` stubs, repositories, coordinator navigation, the product card components and image loader, and memory-leak checks.
- **End to end** against live Fake Store and Mailpit: all 5 criteria, plus unknown product → 404, invalid enquiry → 400, mail server down → 502 (never a false "Thank you").
- **Manually in the Simulator:** Home, Category, enquiry success and failure, the email in Mailpit, Thank you. Details in `docs/TESTING.md`.

Bugs found by testing and fixed in this PR: a Docker file-permission bug, a data race in the iOS test mocks, and a carousel that changed height while scrolling (see `AI_USAGE.md`).

## Key decisions and assumptions

Full list with reasons in `DECISIONS.md`. The most important:

- **"Top rated"** means hand-picked on Home (as the brief says) and ranked by rating on Category pages.
- **"Search button"** is the keyboard's Search key; typing also searches. Matching covers title, description and category.
- **Enquiry fields:** name and email required, phone and message optional. Enquiries aren't stored: the email is the record, and a failure is reported, never hidden.
- **Fake Store's bot protection** is reported as a 502, never bypassed.
- **No UI test target:** testing effort went to ViewModels, networking and navigation, which cover the critical path faster and more reliably.

## Known limitations

- Depends on the public Fake Store API being reachable.
- Enquiries aren't persisted and have no idempotency key; rate limit and cache are in memory, per instance.
- Search has no relevance ranking or pagination (Fake Store has about 20 products).
- iPhone portrait only; no snapshot tests; prices in USD.
- Next steps with another day are in `DECISIONS.md` §9 (persisted enquiries with retries, OpenAPI contract, CI, deployment on AWS).

## Where to look

| File | What's in it |
|---|---|
| `README.md` | Setup, configuration, API and tests |
| `DECISIONS.md` | Assumptions, simplifications, how the design grows, next steps, time spent |
| `AI_USAGE.md` | Tools and model, key prompts, where the AI got things wrong and how it was caught |
| `AGENTS.md` | Instructions given to the AI agent |
| `docs/` | Requirements, architecture and API contract, testing results, code review |

---

## Submission summary (for the email)

> **Kataloq – Product Catalogue Platform.** Repository: https://github.com/kpkcool/kataloq. Pull request: `feature/kataloq-mvp` → `main` (left open).
>
> **Stack:** native iOS app in Swift and UIKit (MVVM-C, iOS 16+) and a Node.js + TypeScript REST API. The API is the only thing that talks to Fake Store and emails enquiries via SMTP; locally Mailpit captures them.
>
> **Run it:** `docker compose up --build -d`, then open `ios/Kataloq.xcodeproj` and press ⌘R. Enquiry emails are at http://localhost:8025. No accounts or keys are needed. `./scripts/verify.sh` runs every test plus an end-to-end check.
>
> **Docs:**
> - `README.md`: setup.
> - `DECISIONS.md`: assumptions, trade-offs, what's next.
> - `AI_USAGE.md`: Claude Opus 5.5, key prompts, AI mistakes and how they were caught.
> - `AGENTS.md`: the agent instructions used.
> - `docs/`: requirements, architecture, testing and code review.
>
> **Time spent:** about 7 hours of wall-clock time over two days (breakdown in `DECISIONS.md` §10), over the 2–3 hour guide mainly because of step-by-step verification and UI polish after Simulator review.
