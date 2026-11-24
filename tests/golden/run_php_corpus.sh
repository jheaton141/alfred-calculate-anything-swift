#!/usr/bin/env zsh
set -euo pipefail
# Runs every query in queries.tsv through the upstream PHP workflow and writes expected_php.jsonl.
cd "${0:A:h}/../.."
export alfred_workflow_data="${PWD}/.data/php" alfred_workflow_cache="${PWD}/.data/php" alfred_workflow_bundleid=x.test
mkdir -p "${alfred_workflow_data}"
: > tests/golden/expected_php.jsonl
while IFS=$'\t' read -r action query; do
  out="$(php tests/golden/run_one.php "${query}" "${${action}:#-}" 2>&1 || true)"
  jq -cn --arg a "${action}" --arg q "${query}" --arg o "${out}" '{action:$a,query:$q,output:$o}' >> tests/golden/expected_php.jsonl
done < tests/golden/queries.tsv
