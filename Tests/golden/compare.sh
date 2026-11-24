#!/usr/bin/env zsh
set -euo pipefail
# Runs the Swift binary on every golden query and prints query, upstream titles, Swift titles, SAME/DIFF.
cd "${0:A:h}/../.."
BIN="$(swift build --scratch-path .build-lead --show-bin-path)/calc"
export alfred_workflow_data="${PWD}/.data/swift"
while IFS= read -r line; do
  action="$(jq -r .action <<<"${line}")"; query="$(jq -r .query <<<"${line}")"
  [[ "${action}" == "color" ]] && continue
  up_t="$(jq -r '.output|fromjson|.items|map(.title)|join(" | ")' <<<"${line}")"
  q="${query}"; [[ "${action}" == "vat" && "${query}" != *vat* ]] && q="vat ${query}"
  sw_t="$("${BIN}" "${q}" | jq -r '.items|map(.title)|join(" | ")')"
  [[ "${up_t}" == "${sw_t}" ]] && st=SAME || st=DIFF
  printf '%s\t%s\t%s\t%s\n' "${st}" "${query}" "${up_t}" "${sw_t}"
done < Tests/golden/expected_upstream.jsonl
