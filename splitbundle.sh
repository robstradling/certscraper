cat "$1" | sed "s/^&gt;//g" | csplit -f "$1-split-" /dev/stdin '/-----BEGIN CERTIFICATE-----/' '{*}'
