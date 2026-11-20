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
| Home shows the 5 chosen products | `FEATURED_PRODUCT_IDS` (exactly 5, validated at startup) → `GET /api/v1/products/featured`. Shown as a horizontal "Featured" carousel, with category chips above. |
| Category: top rated, then additional | `GET /api/v1/categories/:id/products`. The backend ranks by rating score, then rating count (ties keep Fake Store's order). The first 3 are "Top Rated" (carousel); the rest are "All Products" (grid), with no duplicates. |
| Search shows only matches | Search runs on the keyboard's Search button → `GET /api/v1/products/search?q=`. Case-insensitive substring match on title, description and category; Fake Store order kept. Blank or over-long terms are never sent. |
| Product page | Tapping any tile → detail screen with image, category, title, price, rating, description, and a sticky Enquire button. |
| Enquiry → email → thank you | Modal form: name and email required, phone and message optional, validated on the client and on the backend (authoritative). `POST /api/v1/enquiries` sends SMTP to Mailpit and returns `202` **only after the email is accepted**. The form is then replaced by "Thank you". A failure shows an error, keeps the input and allows retry. |

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

*Fill in from the latest `./scripts/verify.sh` run. Copy the real numbers only.*

- Backend: `npm run typecheck` … ; `npm test` … tests passed; `npm run build` …
- iOS: `xcodebuild test` … `Executed N tests, with 0 failures`
- End-to-end (Compose + live Fake Store + Mailpit): AC1–AC5 …; email-provider outage → 502 …
- Manual Simulator walkthrough: `docs/TESTING.md` M1–M13 …

Results already observed during development (backend increments 1–3: 71 / 107 / 137 tests passing; live API and enquiry/outage checks) are recorded with timestamps in `docs/TESTING.md`.

### Known limitations

- **Fake Store dependency:** the demo depends on the public Fake Store API being reachable.
- **Enquiries:** not persisted, and there's no idempotency key on `POST /enquiries`.
- **In memory, per instance:** the rate limit and the cache.
- **Search:** no relevance ranking or pagination.
- **App scope:** iPhone portrait only, and no UI or snapshot tests for screens.
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
> **Time spent:** *[fill in from DECISIONS.md §10]*.
