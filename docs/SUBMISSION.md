# Kataloq – Pull request description and submission summary

## Pull request (feature/kataloq-mvp → main)

**Title:** Kataloq – Product Catalogue Platform (UIKit iOS app + Node.js/TypeScript API)

> Copy everything between the lines into the PR body (`gh pr create --body-file` reads the whole file, so paste this section instead if you use the web UI).

---

### Problem

An entrepreneur needs an interactive proof of concept of a product catalogue that can grow into the real product. The data source, the email provider and the look and feel are all expected to change. Customers must be able to:

- see five hand-picked products on Home;
- browse a category (its top-rated products, then the rest);
- search by text;
- view a product;
- send an enquiry, which emails the sales inbox and shows a thank-you.

### What's implemented

| Acceptance criterion | Implementation |
|---|---|
| Home shows the 5 chosen products | `FEATURED_PRODUCT_IDS` (exactly 5, validated at startup) → `GET /api/v1/products/featured`. Shown as a horizontal "Featured" carousel, with a search bar and category chips above and an "All Products" grid (`GET /api/v1/products`) below. |
| Category: top rated, then additional | `GET /api/v1/categories/:id/products`. The backend ranks by rating score, then rating count (ties keep Fake Store's order). The first 3 are "Top Rated" (carousel); the rest are "All Products" (grid), with no duplicates. |
| Search shows only matches | Search bar on Home; results appear over Home as the user types (300 ms pause, older requests cancelled) and immediately on the keyboard's Search button → `GET /api/v1/products/search?q=`. Case-insensitive substring match on title, description and category; Fake Store order kept. Blank or over-long terms are never sent. |
| Product page | Tapping any tile → detail screen with image, category, title, price, rating, description, and a sticky Enquire button. |
| Enquiry → email → thank you | Modal form (required fields marked with a red `*`): name and email required, phone and message optional, validated on the client and on the backend (authoritative). `POST /api/v1/enquiries` sends SMTP to Mailpit and returns `202` **only after the email is accepted**. The form is then replaced by "Thank you". A failure shows an error, keeps the input and allows retry. |

Every screen has loading, empty and error-with-retry states. Text uses Dynamic Type, and the main elements have VoiceOver labels.

### Architecture

- **iOS (Swift, UIKit, MVVM-C, iOS 16+):** ViewModels with no UIKit own state and intents; ViewControllers only render; one `AppCoordinator` does all navigation. Repositories and the network client sit behind protocols and are injected through a plain `AppDependencies` struct. URLSession with async/await, no third-party dependencies.
- **Backend (Node 26, TypeScript strict, Express 5):** routes → controllers → services → domain, with `ProductProvider` and `EmailProvider` interfaces. Fake Store and SMTP are adapters chosen only in `container.ts`. There's a 60-second caching decorator (failures not cached, concurrent misses share one request), zod validation everywhere, one error handler, request IDs, and JSON logs with no personal data.
- **The app never calls Fake Store for product data.** The backend maps Fake Store into Kataloq's own contract. Images load from the URL the backend returns.
- `docker compose up --build` starts the API and Mailpit. The backend image is AWS-compatible (ECS / App Runner).

### Important decisions

See `DECISIONS.md`. In short:
- **"Top rated":** curated on Home, computed by rating on Category pages.
- **Featured products:** an unavailable one is skipped and logged, never substituted.
- **Fake Store's Cloudflare challenge:** surfaced as `502`, never bypassed.
- **Enquiries:** not stored, and never retried automatically.
- **Testing:** the UI test target was removed in favour of ViewModel, network and coordinator tests.

### Testing performed

Full run of `./scripts/verify.sh` on 2026-11-20 12:35 IST (Xcode 27.2, iPhone 18 Pro Simulator, Docker 29.9.3, Node 26), all **PASS**:

- **Backend:** `npm run typecheck` clean; `npm test` **204/204** (unit + integration); `npm run build` OK.
- **iOS:** `xcodebuild test` **123 tests, 0 failures**.
- **End to end** (Compose + live Fake Store + Mailpit): AC1 featured 1, 5, 9, 14, 18; AC2 electronics top 12, 11, 9 then 10, 13, 14; AC3 `JACKET` → 3, 15, 16, 17, no match → empty, blank → 400; AC4 product details, unknown → 404; AC5 enquiry 202 with the email captured in Mailpit; mail server down → 502, never 202.
- **Manual in the Simulator:** Home, Category, enquiry success and failure, email in Mailpit, Thank you (see `docs/TESTING.md`; remaining manual checks are listed there).

Testing found and fixed: a Docker file-permission bug, a data race in the iOS test mocks, and a carousel that changed height while scrolling (details in `AI_USAGE.md`).

### Known limitations

- **Fake Store dependency:** the demo depends on the public Fake Store API being reachable.
- **Enquiries:** not persisted, and there's no idempotency key on `POST /enquiries`.
- **In memory, per instance:** the rate limit and the cache.
- **Search:** no relevance ranking or pagination.
- **App scope:** iPhone portrait only, and no UI or snapshot tests for screens.
- **iOS tests run serially** (`-parallel-testing-enabled NO`); parallel Simulator clones were unreliable on the test machine and the suite takes under a second anyway.
- **Prices:** shown in USD.

Code review findings and their status: `docs/CODE_REVIEW.md`. How AI was used: `AI_USAGE.md`.

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
