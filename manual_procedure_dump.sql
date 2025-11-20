-- Prepares a deterministic snapshot of tagged Manual Procedure revisions
-- from MediaWiki 1.24.2 for downstream import work.
--
-- Usage (run on the RHEL6 efs3 host):
--   mysql --defaults-file=/root/.my.cnf efs3 < scripts/manual_procedure_dump.sql
--   mysqldump --defaults-file=/root/.my.cnf --skip-add-drop-table --replace efs3 manual_procedure_dump \
--       > manual_procedure_dump.sql
--
-- The resulting manual_procedure_dump.sql can be copied to sh0re/sh1re and
-- imported with:
--   mysql --defaults-file=/root/.my.cnf targetwiki < manual_procedure_dump.sql
--
-- The script is idempotent; rerunning will rebuild the staging table with the
-- latest tagged state.

SET NAMES utf8mb4;
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';

DROP TABLE IF EXISTS manual_procedure_dump;

CREATE TABLE manual_procedure_dump (
    tag_id           VARBINARY(255)  NOT NULL,
    deploy_comment   VARBINARY(1024) NULL,
    page_id          INT UNSIGNED    NOT NULL,
    page_namespace   INT             NOT NULL,
    page_title       VARBINARY(255)  NOT NULL,
    rev_id           INT UNSIGNED    NOT NULL,
    rev_timestamp    BINARY(14)      NOT NULL,
    rev_comment      VARBINARY(1024) NULL,
    rev_user         INT UNSIGNED    NULL,
    rev_user_name    VARBINARY(255)  NULL,
    rev_text_id      BIGINT UNSIGNED NOT NULL,
    wikitext         MEDIUMBLOB      NOT NULL,
    PRIMARY KEY (tag_id, page_id, rev_id),
    KEY idx_page (page_id),
    KEY idx_rev (rev_id),
    KEY idx_tag_title (tag_id, page_title)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO manual_procedure_dump (
    tag_id,
    deploy_comment,
    page_id,
    page_namespace,
    page_title,
    rev_id,
    rev_timestamp,
    rev_comment,
    rev_user,
    rev_user_name,
    rev_text_id,
    wikitext
)
SELECT
    t.tag_id                    AS tag_id,
    t.comment                   AS deploy_comment,
    p.page_id,
    p.page_namespace,
    p.page_title,
    r.rev_id,
    r.rev_timestamp,
    r.rev_comment,
    NULLIF(r.rev_user, 0)       AS rev_user,
    COALESCE(u.user_name, r.rev_user_text) AS rev_user_name,
    r.rev_text_id,
    tx.old_text                 AS wikitext
FROM mw_tag_pages tp
JOIN mw_tags t       ON tp.tag_id    = t.tag_id
JOIN mw_page p       ON tp.tag_page  = p.page_id
JOIN mw_revision r   ON tp.tag_rev   = r.rev_id
LEFT JOIN mw_user u  ON r.rev_user   = u.user_id
JOIN mw_text tx      ON r.rev_text_id = tx.old_id
WHERE t.tag_id IN (
    'ROUTINE_4.106',
    'ROUTINE_4.107',
    'ROUTINE_4.108',
    'ROUTINE_4.109',
    'ROUTINE_4.110'
)
ORDER BY t.tag_id, p.page_title, r.rev_timestamp DESC;
