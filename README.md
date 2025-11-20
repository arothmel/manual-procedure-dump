Manual Procedure Dump
======================

This repo contains a repeatable SQL script that extracts every tagged Manual Procedure revision
from the legacy MediaWiki 1.24.2 database (efs3) and stages it for migration into MediaWiki 1.35.9
(sh0re/sh1re).

How it works
------------
1. `scripts/manual_procedure_dump.sql` drops/rebuilds a staging table named `manual_procedure_dump`.
2. The staging table captures one row per (tag, page, revision) with deploy comments, editor
   metadata, timestamps, and the raw wikitext pulled straight from `mw_text.old_text`.
3. Once populated, you can `mysqldump --replace manual_procedure_dump` to produce an idempotent
   import file that can be copied into any target environment. The `--replace` flag ensures
   duplicates overwrite existing rows when re-imported.

Running the export on efs3
--------------------------
```
# shell variables for clarity; adjust credentials/paths as needed
DB=wikidb
CNF=/root/.my.cnf
OUT=manual_procedure_dump.sql

mysql --defaults-file="$CNF" "$DB" < scripts/manual_procedure_dump.sql
mysqldump --defaults-file="$CNF" --skip-add-drop-table --replace "$DB" manual_procedure_dump > "$OUT"
```

Transferring/importing
----------------------
1. `scp manual_procedure_dump.sql` to your workstation, then into the `mariadb-mw1359` container.
2. On sh0re/sh1re, import with:
   `mysql --defaults-file=/opt/mediawiki/.my.cnf wikidb < manual_procedure_dump.sql`
3. The import can safely be re-run; each row is keyed by `(tag_id, page_id, rev_id)` so later
   loads simply replace matching data.

Next steps
----------
With the data staged in `manual_procedure_dump`, you can:
- dedupe / audit tagged revisions before promoting into the main namespaces,
- wire the new CustomQueryPage extension to read from this table,
- or rehydrate pages via the MediaWiki maintenance scripts using the exported wikitext.
