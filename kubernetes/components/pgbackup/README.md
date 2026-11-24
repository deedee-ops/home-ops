# pgbackup

Restore (drops and recreates the whole database). Stop the app first, nothing can be connected.

```sh
zcat <app>-latest.sql.gz | kubectl -n <ns> exec -i <primary> -c postgres -- sh -c 'cat > /run/r.sql'
kubectl -n <ns> exec <primary> -c postgres -- psql -U postgres -v ON_ERROR_STOP=1 -f /run/r.sql
kubectl -n <ns> exec <primary> -c postgres -- rm /run/r.sql
```

Never skip `ON_ERROR_STOP`: if `DROP DATABASE` fails, the dump is loaded into the existing database.
