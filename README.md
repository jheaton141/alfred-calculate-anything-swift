# Calculate Anything (Swift)

A fork of [biati-digital/alfred-calculate-anything](https://github.com/biati-digital/alfred-calculate-anything), rewritten in Swift. It is a single native binary with no runtime, no API keys and no setup. Type a calculation in Alfred and get the answer.

Enter copies the formatted value, Cmd+Enter copies the raw number, and Alt+Enter copies the value with its unit.

## What changed from upstream

- **No runtime to install.** One universal (Apple silicon and Intel) `calc` binary, under 2 MB.
- **No API keys.** Fiat rates come from [Frankfurter](https://frankfurter.dev) and [fawazahmed0/currency-api](https://github.com/fawazahmed0/exchange-api). Crypto prices come from CoinGecko, with Coinbase spot as the fallback.
- **Works offline.** Rates are cached on disk. If every source is down, the last cached rates are shown and labelled as stale.
- **Fixed upstream bugs:** Fahrenheit to Celsius and Celsius to Kelvin, the UK gallon, millilitres to ounces, VAT rounding, a stray extra row for feet and inches, and doubled spaces in time units.
- **New:** arithmetic and functions, `k`/`M`/`B`/`T` suffixes, more units, more percentage phrasings, timezone conversion with daylight-saving notes (a time that is skipped or repeated on a clock change is flagged), a clear error for unknown zones, date arithmetic (`10 days after`, business days, weekday and week number of a date), compound amounts (`5 ft 3 in to cm`), fuel economy, tip and bill splitting, a rates refresh keyword, colour contrast and lighten/darken.

## Examples

| Tool | Try |
| --- | --- |
| Math | `12*(3+4)`, `2^10`, `sqrt(144)`, `50 % 7`, `1.5k * 3`, `10 + 5 * 2` |
| Currency | `100 usd to eur`, `100€ to $`, `100 usd mxn`, `120 euros` (converts to your base currency) |
| Crypto | `1 btc to usd`, `0.5 eth to eur` |
| Units | `10 km to mi`, `100 f to c`, `2 cups to ml`, `5 stone to kg`, `3 tbsp to tsp`, `1 acre to m2`, `1 furlong to m`, `1 crore to million`, `10 lakh`, `3.2e-5 m to mm`, `5 ft 3 in to cm`, `1h 30m to min`, `30 mpg to l/100km` |
| Data storage | `2 gb to mb`, `400 MiB to kib` |
| Percentage | `20% of 150`, `what is 20% of 150`, `150 + 20%`, `20% off 150`, `50 is what % of 200`, `20 is 10% of what`, `% change from 50 to 75` |
| px / em / rem | `12px to em`, `1.5rem to px` |
| VAT | `100 vat`, `vat 250`, `vat 100 at 5%`, `100 + vat 21%` (a rate in the query overrides the setting) |
| Time | `time +15 years`, `3pm in PT`, `9am EST to Tokyo`, `2025-01-31 + 1 month`, `days until 31 december`, `time 2026-12-25 - today`, `time 1700000000`, `time 10 days after 2026-12-25`, `time 3pm in 5 days`, `time 5 business days from now`, `time business days until 2027-01-01` (weekends skipped, holidays not), `what day is 2026-12-25`, `time week number of 2026-12-25` |
| Tip | `tip 85`, `tip 85 at 18%`, `tip 18% of 85 split 3`, `85 tip 20% between 4` (no rate shows 15, 18, 20 and 25%) |
| Colour | `#ff8800`, `rgb(255,136,0)`, `hsl(32,100%,50%)`, `contrast white vs black`, `lighten #336699 20%`, `darken red 10%` |

## Install

1. Build the package, or download `CalculateAnything.alfredworkflow` if you have one:

   ```sh
   Packaging/build.sh
   ```

   The result is `Packaging/dist/CalculateAnything.alfredworkflow`.
2. Double-click it to import it into Alfred. Alfred 5 with the Powerpack is required.
3. If you downloaded the package in a browser, macOS quarantines the unsigned binary. Clear it once; see [Packaging/README.md](Packaging/README.md) for the command, and for Developer ID signing and notarization.

Rates are stored in the workflow's data folder (`alfred_workflow_data`). Outside Alfred the binary uses `./.data`. To clear the cache, delete `rates-*.json` there, or use the `_caclear` keyword. `_carefresh` forces a refresh now and reports the source and count (or that it stayed offline).

## Keywords

Alfred only runs a workflow for a typed query when a keyword matches. A query that starts with a digit, `.` or `-` always works. For anything else the workflow defines these keywords, which are typed as part of the query: `calc` (or `=`) plus any text, `#`, `(`, `%`, `vat`, `tip`, `time`, `what`, `days`, `contrast`, `lighten`, `darken`, `rgb`, `hsl`, `hsv`, `hwb`, `cmyk`, `lab`, `lch`, `xyz`, and the functions `sqrt`, `abs`, `round`, `floor`, `ceil`, `ln`, `log`, `sin`, `cos`, `tan`, `exp`. Anything else needs the `calc` prefix, for example `calc 100 usd to eur`. `_caclear` clears the rates cache and `_carefresh` refreshes it.

## Configuration

Open the workflow's configuration panel in Alfred. The same names work as environment variables when you run the binary yourself.

| Setting | Default | Meaning |
| --- | --- | --- |
| `language` | `en_EN` | Interface language: `en_EN`, `es_ES` or `sv_SE`. Unknown values fall back to English. |
| `decimal_separator` | `.` | `.` or `,` for typed input and output. Mixed input such as `1.234,56` is detected automatically. |
| `number_grouping` | `western` | `western` (1,234,567) or `indian` (12,34,567) digit grouping in results. |
| `decimals` | `2` | Decimal places, 0 to 12. Rounding is half away from zero. |
| `base_currency` | `USD` | Target for a bare amount such as `120 euros`. |
| `currency_cache_hours` | `6` | How long fiat rates are reused before a refresh. |
| `base_pixels` | `16` | Pixels per em/rem. |
| `vat_percentage` | `16` | Default VAT rate. |
| `timezone` | none | Zone for time answers, for example `Europe/Stockholm`. An unknown value adds a warning row to time answers and the system zone is used. |
| `time_format` | `j F, Y, g:i:s a` | Date format for time answers. |

## Languages

English, Spanish and Swedish packs for the result text are built into the binary (`Sources/CalcCore/LanguagePacks.swift`). Only the interface text is translated; unit names, currency names, weekday and month names, the percentage-change title and the "Total days" rows are English. To add a language, add a pack there with the same keys; a test checks that every pack has the same keys and placeholders as English.

## Develop

```sh
swift build
swift test                   # 248 tests; set RUN_LIVE=1 to include the live-network test
./.build/debug/calc "20% of 150"
Tests/golden/compare.sh      # compares the Swift output with recorded upstream outputs over a query corpus
```

The code is a `CalcCore` library (tools, rates, formatting), a thin `calc` executable and an XCTest target. A tool returns `nil` for queries that are not its own, and the engine takes the first answer in this order: tip, VAT, percentage, px/em/rem, data storage, time, units, crypto, currency, colour, math. See [PLAN.md](PLAN.md) for the design notes, the progress log and the known gaps.

The golden corpus in `Tests/golden/` holds outputs recorded from the upstream workflow; every difference from them was reviewed as an intended fix or addition.

## Known limitations

- Rate sources are free services with no guarantee; if all are down you get cached rates labelled as stale, or an error if nothing was ever cached.
- Dates beyond about year 200,000 return "not a valid date".
- Month arithmetic clamps to the last day of the month (`2025-01-31 + 1 month` is Feb 28; upstream gives Mar 3).
- Bare 10- or 13-digit numbers are read as timestamps, as upstream does.
- Unit conversions show at least 8 decimals regardless of `decimals`, so small results keep their precision.
- Lab and lch print two decimals, so converting them back may differ by one in the last digit.

## License

MIT, as upstream. See [LICENSE](LICENSE).
