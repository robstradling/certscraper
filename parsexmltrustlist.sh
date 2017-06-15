#!/bin/bash

TEMP_DIR=`mktemp -d`
echo $TEMP_DIR

function extractxmlelements() {
  TEMP_FILE=`mktemp -p "$TEMP_DIR"`
  echo $TEMP_FILE
  xml_grep "$2" "$1" | tr -d '\n' | tr -d [:blank:] > "$TEMP_FILE"
  sed -i "s/<\/$2><$2>/\n/g" "$TEMP_FILE"
  sed -i "s/<\/$2>.*$//g" "$TEMP_FILE"
  sed -i "s/^.*<$2>//g" "$TEMP_FILE"
}

extractxmlelements "$1" "X509Certificate"
extractxmlelements "$1" "tsl:X509Certificate"

ADDITIONAL_SUFFIX=`basename "$TEMP_FILE"`
split -l 1 --additional-suffix="$ADDITIONAL_SUFFIX" "$TEMP_FILE"

find . -iname "x*$ADDITIONAL_SUFFIX" -exec ../b64toder.sh '{}' ';'

rm -rf "$TEMP_DIR"
