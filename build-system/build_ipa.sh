#!/usr/bin/env bash
set -eo pipefail

echo "============================================="
echo "   WhiteGram-iOS Automated Build Pipeline    "
echo "============================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONFIGURATION="release"
BUILD_METHOD="auto"
OUTPUT_DIR="${ROOT_DIR}/build/artifacts"
OUTPUT_IPA="${OUTPUT_DIR}/WhiteGram-unsigned.ipa"

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --configuration) CONFIGURATION="$2"; shift ;;
        --method) BUILD_METHOD="$2"; shift ;;
        --output) OUTPUT_IPA="$2"; shift ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

mkdir -p "${OUTPUT_DIR}"

echo "Project Root: ${ROOT_DIR}"
echo "Configuration: ${CONFIGURATION}"
echo "Build Method: ${BUILD_METHOD}"
echo "Output IPA: ${OUTPUT_IPA}"

# Verify Python 3
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is required."
    exit 1
fi

python3 "${SCRIPT_DIR}/Make/Build.py" \
    --configuration="${CONFIGURATION}_arm64" \
    --method="${BUILD_METHOD}" \
    --output="${OUTPUT_IPA}"

# Generate SHA256 Checksum
if [[ -f "${OUTPUT_IPA}" ]]; then
    echo "Generating SHA256 checksum..."
    shasum -a 256 "${OUTPUT_IPA}" > "${OUTPUT_IPA}.sha256"
    cat "${OUTPUT_IPA}.sha256"
    echo "Build artifacts ready in ${OUTPUT_DIR}"
else
    echo "Error: Output IPA ${OUTPUT_IPA} was not created!"
    exit 1
fi
