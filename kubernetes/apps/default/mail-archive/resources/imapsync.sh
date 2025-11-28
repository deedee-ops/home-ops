#!/bin/sh

imapsync \
  --host1 imap.migadu.com \
  --user1 "$(cat /secrets/SOURCE_USER)" \
  --passfile1 "/secrets/SOURCE_PASS" \
  --ssl1 \
  --host2 "mail-archive-dovecot" \
  --user2 "$(cat /secrets/DESTINATION_USER)" \
  --passfile2 "/secrets/DESTINATION_PASS" \
  --usecache \
  --exclude "INBOX|Sent|Drafts|Junk|Trash" \
  --nofoldersizes \
  --tmpdir "/data" \
  --logdir "/data" \
  --logfile "log.txt" \
  --pidfile "/data/imapsync.pid"
