#!/usr/bin/env bash
# File layout and retention compatible with prodrigestivill/postgres-backup-local
set -Eeuo pipefail

umask 0022
cd "$BACKUP_DIR"
mkdir -p last daily weekly monthly

now=$(date +%s)
last="$PGDATABASE-$(date -d "@$now" +%Y%m%d-%H%M%S).sql.gz"
daily="$PGDATABASE-$(date -d "@$now" +%Y%m%d).sql.gz"
weekly="$PGDATABASE-$(date -d "@$now" +%G%V).sql.gz"
monthly="$PGDATABASE-$(date -d "@$now" +%Y%m).sql.gz"

tmp="last/.$last.partial"
trap 'rm -f "$tmp"' EXIT
find last -maxdepth 1 -name ".$PGDATABASE-*.partial" -mmin +120 -delete

pg_dump --clean --if-exists --create --inserts --compress=gzip:6 --file="$tmp"
gzip -t < "$tmp"
mv "$tmp" "last/$last"

ln -f "last/$last" "daily/$daily"
ln -f "last/$last" "weekly/$weekly"
ln -f "last/$last" "monthly/$monthly"

ln -sf "$last" "last/$PGDATABASE-latest.sql.gz"
ln -sf "$daily" "daily/$PGDATABASE-latest.sql.gz"
ln -sf "$weekly" "weekly/$PGDATABASE-latest.sql.gz"
ln -sf "$monthly" "monthly/$PGDATABASE-latest.sql.gz"

find last -maxdepth 1 -mmin +240 -name "$PGDATABASE-*.sql.gz" -print -delete
find daily -maxdepth 1 -mtime +14 -name "$PGDATABASE-*.sql.gz" -print -delete
find weekly -maxdepth 1 -mtime +1 -name "$PGDATABASE-*.sql.gz" -print -delete
find monthly -maxdepth 1 -mtime +1 -name "$PGDATABASE-*.sql.gz" -print -delete

echo "created last/$last ($(stat -c %s "last/$last") bytes)"
