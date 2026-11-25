#!/usr/bin/env zsh
set -euo pipefail

# Builds the universal calc binary and zips it with info.plist and assets into an .alfredworkflow.
ROOT="${0:A:h:h}"
cd "${ROOT}"
DIST="${ROOT}/Packaging/dist"
STAGE="${DIST}/stage"
OUT="${DIST}/CalculateAnything.alfredworkflow"
SIGN_ID="${SIGN_IDENTITY:--}"

rm -rf "${DIST}"
mkdir -p "${STAGE}"

swift build -c release --arch arm64 --arch x86_64 --scratch-path "${ROOT}/.build-pkg"
BIN="$(swift build -c release --arch arm64 --arch x86_64 --scratch-path "${ROOT}/.build-pkg" --show-bin-path)/calc"

# Fail unless both architectures are present.
INFO="$(lipo -info "${BIN}")"
print -r -- "${INFO}"
[[ "${INFO}" == *arm64* && "${INFO}" == *x86_64* ]] || { print -u2 "binary is not universal"; exit 1; }

cp "${BIN}" "${STAGE}/calc"
cp "${ROOT}/info.plist" "${STAGE}/info.plist"
cp "${ROOT}/icon.png" "${STAGE}/icon.png"

# Per-object icons named after the object UID.
for png in "${ROOT}"/[0-9A-F]*-*-*-*-*.png(N); do cp "${png}" "${STAGE}/"; done

# Copy only the files the plist readme references.
for ref in ${(f)"$(grep -o '\./assets/[A-Za-z0-9_./-]*' "${ROOT}/info.plist" | sort -u)"}; do
  mkdir -p "${STAGE}/${ref:h}"
  cp "${ROOT}/${ref}" "${STAGE}/${ref}"
done

if [[ "${SIGN_ID}" == "-" ]]; then
  codesign -s - --force "${STAGE}/calc"
else
  codesign -s "${SIGN_ID}" --force --options runtime --timestamp "${STAGE}/calc"
fi
codesign -dv "${STAGE}/calc" 2>&1 | grep -E 'Signature|Identifier' || true

(cd "${STAGE}" && zip -qry "${OUT}" .)
rm -rf "${STAGE}"
print "size: $(du -h "${BIN}" | cut -f1) binary, $(du -h "${OUT}" | cut -f1) zip"
print "sha256: $(shasum -a 256 "${OUT}")"
