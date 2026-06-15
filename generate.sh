#!/usr/bin/env bash
# ============================================================================
# Batch / single name-tag STL generator.
#
#   ./generate.sh                 # read names from names.txt (one per line)
#   ./generate.sh "Anna" "Jörg"   # one STL per name argument
#
# Output goes to ./out/<sanitized-name>.stl
# ============================================================================
set -euo pipefail

# Resolve paths relative to this script so it works from any directory.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCAD="$SCRIPT_DIR/nametag.scad"
OUT_DIR="$SCRIPT_DIR/out"
NAMES_FILE="$SCRIPT_DIR/names.txt"

OPENSCAD="${OPENSCAD:-openscad}"   # override with OPENSCAD=/path/to/openscad

mkdir -p "$OUT_DIR"

# Turn an arbitrary name into a safe filename:
#   lowercase, spaces -> _, keep Unicode letters (umlauts/accents),
#   drop only characters that are unsafe in a filename.
sanitize() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | tr ' ' '_' \
        | tr -d '/\\:*?"<>|'      # strip filesystem-unsafe chars, keep ä ö ü etc.
}

render() {
    local name="$1"
    local safe
    safe="$(sanitize "$name")"
    [ -n "$safe" ] || safe="tag"
    local out="$OUT_DIR/$safe.stl"

    echo ">> $name  ->  $out"
    "$OPENSCAD" --enable=textmetrics \
        -D "name=\"$name\"" \
        -o "$out" \
        "$SCAD"
}

# Collect names: from arguments if given, otherwise from names.txt.
names=()
if [ "$#" -gt 0 ]; then
    names=("$@")
else
    if [ ! -f "$NAMES_FILE" ]; then
        echo "No names given and $NAMES_FILE not found." >&2
        echo "Usage: $0 \"Name1\" \"Name2\"   or put names in names.txt" >&2
        exit 1
    fi
    # Read line by line; skip blank lines and # comments.
    while IFS= read -r line || [ -n "$line" ]; do
        line="${line#"${line%%[![:space:]]*}"}"   # ltrim
        line="${line%"${line##*[![:space:]]}"}"    # rtrim
        [ -z "$line" ] && continue
        case "$line" in \#*) continue ;; esac
        names+=("$line")
    done < "$NAMES_FILE"
fi

if [ "${#names[@]}" -eq 0 ]; then
    echo "No names to render." >&2
    exit 1
fi

for n in "${names[@]}"; do
    render "$n"
done

echo "Done. ${#names[@]} tag(s) in $OUT_DIR/"
