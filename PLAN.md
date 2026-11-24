# Fork plan: alfred-calculate-anything -> Swift

Upstream: https://github.com/biati-digital/alfred-calculate-anything (MIT, PHP, ~9k lines, dormant since Jan 2024).
Toolchain on this Mac: Swift 6.4.2, Xcode installed.

## Goals
1. Remove the PHP runtime dependency (compiled universal binary).
2. Remove every API key (keyless fiat + crypto rates, disk cache, offline fallback).
3. Fix the open upstream issues and add the missing features.

## Remote and licence
- Upstream cloned into this folder with history; upstream kept as `upstream` remote.
- `origin` created on self-hosted Gitea with `gitea-init` (private by default). No GitHub fork is created unless you ask.
- MIT licence retained; add a fork notice to the README.

## Architecture
- Swift package, single executable target `calc` plus library target `CalcCore` (parsing, units, rates) so it is unit-testable.
- Alfred Script Filter contract: `calc "<query>"` prints Alfred JSON (`items`). The `info.plist` workflow calls the binary directly.
- Local storage (this folder, per your instruction): `./.data/` holds `rates-fiat.json`, `rates-crypto.json` and `settings.json`. At install time the path is Alfred's workflow data dir (`alfred_workflow_data`), with the folder above as the dev default.
- Dependencies: none beyond Foundation (dates and timezones via `Foundation.TimeZone`; replaces `jenssegers/date`).

## Rates (no keys)
| Need | Primary | Fallback |
|---|---|---|
| Fiat | Frankfurter (ECB) | fawazahmed0/currency-api (CDN, 200+ currencies) |
| Crypto | CoinGecko public `simple/price` | Coinbase public spot price (Binance returns HTTP 451 from the US) |
- Cache with a TTL (default 6 h fiat, 5 min crypto); on network failure serve the stale cache and label it as stale in the subtitle.
- Endpoints, limits and terms are verified by live calls in phase 2 before they are relied on.

## Phases
1. **Characterize upstream (tests first).** Build a corpus of query -> expected output from the PHP version (runs under `brew php`) across units, percentage, VAT, px/em/rem, data storage, colour, time. These become golden tests for the Swift port. This is the "old vs new on real inputs" equivalence check.
2. **Rates layer.** Fetchers, cache, fallback, tests with recorded fixtures plus a live smoke test.
3. **Port tools in order of risk:** units (table-driven), data storage, percentage, VAT, px/em/rem, currency, crypto, time/dates, colour. Language packs (`en`, `es`, `sv`) move from PHP arrays to JSON.
4. **Alfred packaging.** Universal (arm64 + x86_64) build, ad-hoc or Developer ID signing, notarization if you have a certificate, new `info.plist`, `.alfredworkflow` bundle script.
5. **Features and fixes** (each with a failing test first):
   - Units: cups, tsp, tbsp, UK pint and gallon, ml to fl oz without specifying the type, area units, correct feet for exact multiples of 12 inches.
   - Number suffixes (`10M eur in usd`, k/M/B/T).
   - Timezone conversions (`3pm EST in Tokyo`).
   - Bugs: percentage calculation edge case, `1.234,56` format in percentages, date conversion on macOS 15+.
   - Offline cached rates; no key settings at all.
6. **Verification.** Full test suite, golden-corpus comparison against PHP with a per-case diff report (intended differences listed), then an adversarial subagent pass on the final diff.

## Execution
Phases 1 and 2 are independent and can run in parallel with subagents; 3 needs the shared `CalcCore` types written first by the main session; 4 and 5 follow.

## Open decisions
- Signing: ad-hoc (users right-click Open once) or Developer ID + notarization?
- Keep `en`/`es`/`sv` languages only, or English only first?
- Gitea repo name: `alfred-calculate-anything-swift` unless you prefer another.

## Progress log
- Phase 0 done: branch `feat/swift-rewrite`, Gitea origin `Joe/alfred-calculate-anything-swift`, upstream remote kept.
- Endpoint probe (2026-11-23): Frankfurter 200, fawazahmed0 (fiat and crypto) 200, CoinGecko 200, Coinbase spot 200, Binance 451 (blocked from the US, dropped).
- Phase 1 started: `tests/golden/` holds 69 queries and the PHP outputs (`expected_php.jsonl`, regenerate with `run_php_corpus.sh`). The corpus already exposes upstream bugs that Swift should fix on purpose: 100 F to C gives 37.7, 30 C to K gives 303.1, UK gallon gives 4.405, 1 ml to oz errors, and cup, tbsp, tsp, stone, area units and "what is 20% of 150" return nothing. Currency, crypto and time are not in the PHP corpus (they need keys or the Date package) and get fixture tests in Swift instead.
- Phases 2-3 first wave done (2026-11-23): rates layer, units, currency, crypto, data storage, px/em/rem, VAT, percentage and math ported; 71 tests pass (1 live test skipped unless RUN_LIVE=1). `Tests/golden/compare.sh` runs the Swift binary over the corpus: 23 same, 41 different, and every difference reviewed as an intended fix or addition (exact constants, new units, new percentage and math forms, single-space time units, VAT rounding, the dropped "7 ft, 12 in" extra row). Live check: `100 usd to eur` gives 91.42 EUR and `1 btc to usd` about 60.8k USD with no API key.
- Known gaps: time/timezone, colour, language packs, Alfred packaging (info.plist, universal build, signing), auto-detecting "1.234,56" when the decimal setting is ".", adversarial review pass (math and percentage mutations not yet tried).
- Wave 2 done (2026-11-23): time/timezone and colour tools, Alfred packaging (universal ad-hoc-signed binary, 1.6M), adversarial review fixes (half-away rounding, separator auto-detect, math depth cap, rate validation, stale crypto flag). 122 tests pass. Remaining: adversarial pass on time and colour (running), language packs (en/es/sv), README rewrite, optional Developer ID signing and notarization.
- Review of time and colour (2026-11-23) fixed: colour NaN/inf crash, CSS-correct percentage rgb, `3pm in PT` (Time now runs before Units). Known and deferred: years beyond about 400k print wrong in formatted dates; nonexistent local times inside a DST gap resolve inconsistently (Lord Howe, Auckland, `2:30am` on spring-forward day); calendar is not proleptic Gregorian before 1582; xyz output can differ by one in 3 of 309 random colours; alpha is dropped for hsv/hwb/cmyk/lab/lch/xyz; month arithmetic clamps (2025-01-31 + 1 month = 2025-02-28, PHP gives Mar 3); bare 10- and 13-digit numbers are read as timestamps.
- Pending items closed (2026-11-23): language packs (en/es/sv), README rewrite, root info.plist, translated percentage-change and total rows, proleptic Gregorian time maths, single DST-gap resolver (gap shifts forward), far-year guard (about 200k), colour alpha for all spaces, exact xyz round-trip. Month clamping and bare timestamp reading kept on purpose. Signing stays ad-hoc.
