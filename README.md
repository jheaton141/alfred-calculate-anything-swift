# Calculate Anything (Swift)

A fork of [biati-digital/alfred-calculate-anything](https://github.com/biati-digital/alfred-calculate-anything), rewritten in Swift. It is a single native binary: no PHP, no API keys, no setup. Type a calculation in Alfred and get the answer.

Enter copies the formatted value, Cmd+Enter copies the raw number, and Alt+Enter copies the value with its unit.

## What changed from upstream

- **No PHP.** One universal (Apple silicon and Intel) `calc` binary, about 1.6 MB.
- **No API keys.** Fiat rates come from [Frankfurter](https://frankfurter.dev) and [fawazahmed0/currency-api](https://github.com/fawazahmed0/exchange-api). Crypto prices come from CoinGecko, with Coinbase spot as the fallback.
- **Works offline.** Rates are cached on disk. If every source is down, the last cached rates are shown and labelled as stale.
- **Fixed upstream bugs:** Fahrenheit to Celsius and Celsius to Kelvin, the UK gallon, millilitres to ounces, VAT rounding, a stray extra row for feet and inches, and doubled spaces in time units.
- **New:** arithmetic and functions, `k`/`M`/`B`/`T` suffixes, more units, more percentage phrasings, timezone conversion, colour contrast and lighten/darken.

## Examples

| Tool | Try |
| --- | --- |
| Math | `12*(3+4)`, `2^10`, `sqrt(144)`, `50 % 7`, `1.5k * 3`, `10 + 5 * 2` |
| Currency | `100 usd to eur`, `100€ to $`, `100 usd mxn`, `120 euros` (converts to your base currency) |
| Crypto | `1 btc to usd`, `0.5 eth to eur` |
| Units | `10 km to mi`, `100 f to c`, `2 cups to ml`, `5 stone to kg`, `3 tbsp to tsp`, `1 acre to m2` |
| Data storage | `2 gb to mb`, `400 MiB to kib` |
| Percentage | `20% of 150`, `what is 20% of 150`, `150 + 20%`, `20% off 150`, `50 is what % of 200`, `20 is 10% of what`, `% change from 50 to 75` |
| px / em / rem | `12px to em`, `1.5rem to px` |
| VAT | `100 vat`, `vat 250` |
| Time | `time +15 years`, `3pm in PT`, `9am EST to Tokyo`, `2025-01-31 + 1 month`, `days until 31 december`, `time 2026-12-25 - today`, `time 1700000000` |
| Colour | `#ff8800`, `rgb(255,136,0)`, `hsl(32,100%,50%)`, `contrast white vs black`, `lighten #336699 20%`, `darken red 10%` |

## Install

1. Build the package, or download `CalculateAnything.alfredworkflow` if you have one:

   ```sh
   Packaging/build.sh
   ```

   The result is `Packaging/dist/CalculateAnything.alfredworkflow`.
2. Double-click it to import it into Alfred. Alfred 5 with the Powerpack is required.
3. If you downloaded the package in a browser, macOS quarantines the unsigned binary. Clear it once; see [Packaging/README.md](Packaging/README.md) for the command, and for Developer ID signing and notarization.

Rates are stored in the workflow's data folder (`alfred_workflow_data`). Outside Alfred the binary uses `./.data`. To clear the cache, delete `rates-*.json` there, or use the `_caclear` keyword.

## Configuration

Open the workflow's configuration panel in Alfred. The same names work as environment variables when you run the binary yourself.

| Setting | Default | Meaning |
| --- | --- | --- |
| `language` | `en_EN` | Interface language: `en_EN`, `es_ES` or `sv_SE`. Unknown values fall back to English. |
| `decimal_separator` | `.` | `.` or `,` for typed input and output. Mixed input such as `1.234,56` is detected automatically. |
| `decimals` | `2` | Decimal places, 0 to 12. Rounding is half away from zero. |
| `base_currency` | `USD` | Target for a bare amount such as `120 euros`. |
| `currency_cache_hours` | `6` | How long fiat rates are reused before a refresh. |
| `base_pixels` | `16` | Pixels per em/rem. |
| `vat_percentage` | `16` | Default VAT rate. |
| `timezone` | none | Zone for time answers, for example `Europe/Stockholm`. |
| `time_format` | `j F, Y, g:i:s a` | Date format for time answers. |

## Languages

English, Spanish and Swedish packs for the result text are built into the binary (`Sources/CalcCore/LanguagePacks.swift`). Only the interface text is translated; unit names, currency names, weekday and month names, the percentage-change title and the "Total days" rows are English. To add a language, add a pack there with the same keys; a test checks that every pack has the same keys and placeholders as English.

## Develop

```sh
swift build
swift test                   # 130 tests; set RUN_LIVE=1 to include the live-network test
./.build/debug/calc "20% of 150"
Tests/golden/compare.sh      # compares the Swift output with the original PHP over a query corpus
```

The code is a `CalcCore` library (tools, rates, formatting), a thin `calc` executable and an XCTest target. A tool returns `nil` for queries that are not its own, and the engine takes the first answer in this order: VAT, percentage, px/em/rem, data storage, time, units, crypto, currency, colour, math. See [PLAN.md](PLAN.md) for the design notes, the progress log and the known gaps.

The original PHP sources (`workflow/`, `process.php`, `lang/`, `composer.json`) are kept only so the golden comparison can run the old code. They are not part of the Swift workflow.

## Known limitations

- Rate sources are free services with no guarantee; if all are down you get cached rates labelled as stale, or an error if nothing was ever cached.
- Years beyond about 400,000, dates before 1582, and local times that fall inside a daylight-saving gap are handled approximately.
- Month arithmetic clamps to the last day of the month (`2025-01-31 + 1 month` is Feb 28).
- Bare 10- or 13-digit numbers are read as timestamps.
- Alpha is dropped when converting to hsv, hwb, cmyk, lab, lch and xyz.

## License

MIT, as upstream. See [LICENSE](LICENSE).
