#!/usr/bin/env bash
set -euo pipefail

# Dumps manual_procedure_dump rows into separate files per tag so imports can be chunked.
usage() {
    cat <<'USAGE'
Usage: split_manual_procedure_dump.sh [options]

Options:
  -o, --out-dir DIR     Directory to write files into (default: current directory)
  -p, --prefix NAME     File prefix (default: manual_procedure_dump)
  -h, --help            Show this help text

Environment overrides:
  DB         Database name (default: wikidb)
  CNF        MySQL defaults file (default: /root/.my.cnf)
  MYSQL      mysql client binary (default: mysql)
  MYSQLDUMP  mysqldump binary (default: mysqldump)
USAGE
}

OUT_DIR="."
OUT_PREFIX="manual_procedure_dump"

while [[ $# -gt 0 ]]; do
    case "$1" in
        -o|--out-dir)
            OUT_DIR="$2"
            shift 2
            ;;
        -p|--prefix)
            OUT_PREFIX="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

DB="${DB:-wikidb}"
CNF="${CNF:-/root/.my.cnf}"
MYSQL="${MYSQL:-mysql}"
MYSQLDUMP="${MYSQLDUMP:-mysqldump}"
MYSQLDUMP_OPTS=("--skip-add-drop-table" "--replace")

mkdir -p "$OUT_DIR"

readarray -t TAGS < <("$MYSQL" --defaults-file="$CNF" "$DB" -N -B -e "SELECT DISTINCT tag_id FROM manual_procedure_dump ORDER BY tag_id")

if [[ ${#TAGS[@]} -eq 0 ]]; then
    echo "No tags found in manual_procedure_dump; ensure the staging table is populated first." >&2
    exit 1
fi

sql_escape() {
    sed "s/'/''/g" <<< "$1"
}

for tag in "${TAGS[@]}"; do
    [[ -n "$tag" ]] || continue
    outfile="$OUT_DIR/${OUT_PREFIX}_${tag}.sql"
    where="tag_id = '$(sql_escape "$tag")'"
    echo "Writing $outfile"
    "$MYSQLDUMP" --defaults-file="$CNF" "${MYSQLDUMP_OPTS[@]}" "$DB" manual_procedure_dump --where="$where" > "$outfile"

done

echo "Done. Generated ${#TAGS[@]} files under $OUT_DIR."
