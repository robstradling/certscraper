#!/bin/bash
cat "$1" | sed "s/^&gt;//g" | csplit -f "$1-split-" /dev/stdin '/-----BEGIN CERTIFICATE-----/' '{*}'
find -wholename "$1-split-*" -exec sed -i "s/-----END CERTIFICATE-----/-----END CERTIFICATE-----\n/g" '{}' ';'
