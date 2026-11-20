# How AI was used to build Kataloq

## Tools and model

| | |
|---|---|
| Assistant | **Claude**, model **Claude Opus 5.5** (`claude-opus-5-5`) |
| Surface | Claude's agent mode in the Claude app (an agent harness built on Claude Code), in one long session on 2026-11-19. The project brief named Claude Code as the tool; this is the same agent tooling, used through the Claude app rather than the terminal CLI. |
| Repo access | The local `Kataloq` folder on the Mac was connected through the Claude desktop app. Claude wrote files into it; **the engineer ran every `npm`, `docker`, `xcodebuild` and `git` command on the Mac** and pasted the output back. |
| Guidance given to the agent | A Claude Project with a phase-by-phase prompt pack (requirements → architecture → backend → iOS → testing → review → docs), a working agreement ("small stages, never move on without approval, never claim tests passed without running them"), naming rules, and an engineering-guidelines doc. Those guidelines are committed as [`AGENTS.md`](AGENTS.md). |
| Plan / spec produced first | [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md) (requirements, traceability matrix, 18 ambiguities with proposed assumptions) and [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) (architecture, API contract, models, test strategy, decisions D1–D15), each approved before any code was written. |

### Environment constraints (relevant to how results were verified)

- Claude's sandboxes had **no access to npm or Fake Store** and **no Swift compiler**. Claude could not install packages, run the backend, or build the iOS app.
- To catch mistakes before handing code over, Claude **type-checked backend code with TypeScript 7 and dry-ran its tests with a minimal local stand-in for vitest**. These dry runs were always reported as dry runs, never as test results.
- **Every result in [`docs/TESTING.md`](docs/TESTING.md) comes from output the engineer pasted from the Mac.** Where no output was seen (notably iOS XCTest runs), it says *Pending*.

## How Claude was used

**Planning.** Claude read the assignment PDF and produced the requirements document: functional and non-functional requirements, user stories, acceptance criteria, a traceability matrix, and every ambiguity with a proposed assumption. It then produced the architecture in three revisions, each updated with the engineer's decisions and a conflict check between them. Claude also checked facts it couldn't assume: it confirmed that Xcode 27 supports an iOS 16 deployment target and that Node 26 is the current LTS. It had the engineer verify Fake Store's live behaviour (unknown IDs return `200` with an empty body; categories).

**Implementation.** The backend was written in five increments: config and Fake Store adapter and cache; catalogue rules; HTTP layer; enquiry and email; Docker and docs. The engineer ran the type-check and tests after each. The iOS app was written screen by screen: foundation and Home, then Category, Search, Product detail, and Enquiry with Thank you. Claude also edited the Xcode project settings: iOS 16, no storyboard, UI test target removed, ATS for localhost only.

**Tests.** Claude wrote tests with each increment: backend unit and integration tests (vitest, supertest) and iOS XCTest (ViewModels, networking via `URLProtocol` stubs, repositories, coordinator, leak checks). It also wrote `scripts/verify.sh`, which runs everything plus an end-to-end smoke test against live Fake Store and Mailpit.

**Review.** In Phase 6 Claude ran a structured self-review with automated scans; see [`docs/CODE_REVIEW.md`](docs/CODE_REVIEW.md). Two findings were fixed and nine were documented. The review was done by the same assistant that wrote the code, and the review document says so.

## How generated code was reviewed

- **Approval gates.** Nothing was implemented until the requirements and architecture were approved, and each backend increment and iOS screen was reviewed before the next one started.
- **Tests run by the engineer.** The backend type-check, tests and build were run on the Mac after increments 1–3 (71 → 107 → 137 tests, all passing).
- **Live checks.**
  - **Catalogue:** curl calls against the running API confirmed the featured IDs, the category ranking, search, 404 handling and cache timing.
  - **Enquiry and outage:** a real enquiry with Mailpit returned `202`, and stopping Mailpit gave `502`, never a false success.
  - **iOS:** the app was run in the Simulator, and a screenshot was used to judge the UI.
- **Claude's own checks.** Claude type-checked and dry-ran code before each hand-over, and re-read code for issues before the first run (see mistake 4 below).

## Key prompts and moments that shaped the implementation

1. **"Identify every ambiguity… Do not silently invent requirements."** (Phase 1 prompt.) Claude listed 18 ambiguities with proposed assumptions. The engineer overrode the most important one. Claude had proposed treating a category's "top rated" products as the curated featured products. The engineer chose **ranking by Fake Store's rating score, then rating count, keeping Fake Store's order for ties**, with exactly 3 shown in "Top Rated".
2. **Image delivery conflict.** While integrating Fake Store, Claude noticed that product images are hosted on `fakestoreapi.com`, which conflicts with the rule "the app must never call Fake Store". It offered two options: load the URL the backend returns, or build a backend image proxy. The engineer chose to **load backend-supplied image URLs directly**, documented as "product data goes through our backend; static images can come from an image host".
3. **Fake Store's Cloudflare challenge.** One of the engineer's `curl -I` checks returned `403` with `cf-mitigated: challenge`. Claude declined to work around the bot protection. It made the backend detect the challenge and report it as `502`, and proposed an opt-in fixture data source. The engineer then confirmed that Node's `fetch` gets `200`, so the fixture source was deferred.
4. **Live failure test: "stop Mailpit and send an enquiry".** The API correctly returned `502 EMAIL_DELIVERY_FAILED`. But the log showed an `AggregateError` with an **empty message**, which would be useless in an incident. The logger was changed to record error codes and inner errors.
5. **"UI can be better, with horizontal scrolling items like shopping apps."** (Engineer, after the first Simulator screenshot.) This led to the carousel redesign of Home and Category. The same screenshot exposed a real layout bug (mistake 1 below).

## Mistakes made by the AI, and how they were caught

| # | Mistake | How it was detected | Correction |
|---|---|---|---|
| 1 | The 2-column product grid used `NSCollectionLayoutGroup.horizontal(…, repeatingSubitem:count: 2)` with full-width items, assuming UIKit would size each item to half the width. It didn't: each card filled the screen and the second column was off-screen. | The engineer's Simulator screenshot | Items are explicitly `fractionalWidth(0.5)` with spacing from insets, in a shared `LayoutSections` used by every grid |
| 2 | A Node one-liner Claude gave for checking Fake Store data had an extra `)` and failed with a `SyntaxError`. | The engineer ran it | Corrected command supplied |
| 3 | The logger dropped the useful part of Node network errors (`code: ECONNREFUSED`, the inner errors of an `AggregateError`), leaving an empty message. | Live Mailpit-outage test (moment 4) | Logger now records `code` and inner errors; tests added |
| 4 | The first request-logging middleware logged `req.path`, which inside a mounted Express router can lose the `/api/v1` prefix. | Claude's own re-read before the code was first run | Path taken from `req.originalUrl` at request start, without the query string |
| 5 | Claude said increment 3 added 34 integration tests; the run showed 30. | Comparing with the vitest output | Corrected in the next message |
| 6 | The architecture assumed library majors (nodemailer 7, express-rate-limit 7); npm installed nodemailer 10 and express-rate-limit 8. | `package.json` after install | Code kept to stable APIs; nothing broke |

Not counted as mistakes: proposals the engineer chose differently, such as the "top rated" definition, the tie-break rule, the "More in <Category>" label (became "All Products") and the fixture data source. They are recorded as decisions in `DECISIONS.md`.

## Decisions made by the engineer (not delegated)

- **Platform and stack:** native iOS with UIKit and MVVM-C, and a Node.js + TypeScript backend.
- **Category rules:** "Top Rated" ranked by rating score, then rating count, then Fake Store's order. Exactly 3 products, configurable. The rest go under "All Products" with no duplicates.
- **Search and featured:** search keeps Fake Store's order with no relevance ranking. Missing featured products are skipped and logged, never substituted.
- **Enquiry:** name and email required, phone and message optional, with backend validation authoritative.
- **Local setup:** Mailpit via Docker Compose, with one command starting the backend and Mailpit, and a 60-second cache with shared in-flight requests.
- **Project setup:** iOS 16 minimum, the UI test target removed, and a single repo with `ios/`, `backend/` and `docs/`.
- **Product images:** loaded directly from the backend-supplied URL, with no image proxy.
- **Verification:** run locally on the Mac. The fixture data source was not built.
- **UI direction:** shopping-app style horizontal carousels.
- Approval of every phase before the next began.

## What still needs a human

- Run `./scripts/verify.sh` and the manual checklist in `docs/TESTING.md`, and fill in the *Pending* rows from real output.
- Adjust the time-spent table in `DECISIONS.md` to actual effort.
- Open the pull request (`docs/SUBMISSION.md` has the description) and keep it open.
