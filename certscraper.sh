#!/bin/bash

# Create a temporary working directory.
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
WORK_DIR=`mktemp -d -p "$DIR"`
if [[ ! "$WORK_DIR" || ! -d "$WORK_DIR" ]]; then
  echo "Could not create temporary directory"
  exit 1
fi

function cleanup {
  rm -rf "$WORK_DIR"
}

# Register the cleanup function to be called on the EXIT signal.
trap cleanup EXIT

# Download the supplied URL and extract a list of links.
# Exclude *.crl and *.pdf, because these files are almost certainly not certificates (and they might be huge!)
echo -e "\nDownloading $1..."
INPUT_FILE=`mktemp -p "$WORK_DIR"`
wget -nv -O "$INPUT_FILE" -U certscraper "$1"
echo -e "\nExtracting links from $1..."
lynx -dump -force_html -listonly -useragent=certscraper "$1" 2>/dev/null | grep "://" | sed "s/^.* //g" | grep -v "\.crl$" | grep -v "\.pdf$" > "$WORK_DIR/urls.txt"

# Download each of the extracted links in the temporary directory.
cd "$WORK_DIR"
echo -e "\nDownloading files..."
wget -nv -U "MSIE" -i urls.txt

# Attempt to parse each of the downloaded files as: a PEM certificate, a DER certificate.
echo -e "\nParsing certificates..."
TMP_DIR="$WORK_DIR/tmp"
mkdir "$TMP_DIR"
find -maxdepth 1 -type f -exec openssl x509 -in '{}' -out "$TMP_DIR/{}.crt" 2>/dev/null ';'
find -maxdepth 1 -type f -exec openssl x509 -inform der -in '{}' -out "$TMP_DIR/{}.crt" 2>/dev/null ';'
# TODO: Also attempt to parse as (PEM or DER) PKCS#7, .zip, .tgz.
cd "$TMP_DIR"
ls -1 | sed "s/.crt$//g"

# Create output directory, if it doesn't already exist.
CERT_DIR="../../certs_scraped"
mkdir -p "$CERT_DIR/crt"
mkdir -p "$CERT_DIR/json"
mkdir -p "$CERT_DIR/sct"
mkdir -p "$CERT_DIR/source"

# Process each successfully parsed certificate.
echo -e "\nBuilding JSON to submit to /ct/v1/add-chain..."
for f in *.crt; do
  if [ -e "$f" ]; then
    # Rename the certificate file to <SHA-256(Certificate)>.crt.
    SHA256_FINGERPRINT=`openssl x509 -fingerprint -sha256 -in "$f" -noout | sed "s/^SHA256 Fingerprint=//g" | sed "s/://g"`
    CERT_FILENAME="$SHA256_FINGERPRINT.crt"
    mv "$f" "$CERT_FILENAME"
    # Record where this certificate was found.
    echo "$1" >> "$CERT_DIR/source/$SHA256_FINGERPRINT.txt"
    sort "$CERT_DIR/source/$SHA256_FINGERPRINT.txt" | uniq > "$CERT_DIR/source/$SHA256_FINGERPRINT.temp"
    mv "$CERT_DIR/source/$SHA256_FINGERPRINT.temp" "$CERT_DIR/source/$SHA256_FINGERPRINT.txt"
    # URL-encode this certificate.
    echo -n "b64cert=" > "$CERT_FILENAME.urlencoded"
    perl -MURI::Escape -ne 'print uri_escape($_)' "$CERT_FILENAME" >> "$CERT_FILENAME.urlencoded"
    # Use crt.sh's Certificate Submission Assistant to prepare the JSON data to submit to /ct/v1/add-chain.
    wget -nv --content-disposition --post-file "$CERT_FILENAME.urlencoded" https://crt.sh/gen-add-chain
    rm "$CERT_FILENAME.urlencoded"
  fi
done
for acj in *_UNKNOWN.add-chain.json; do
  if [ -e "$acj" ]; then
    echo -e "\nSubmitting $acj"
    wget -nv -O "$acj.sct.dodo" --post-file "$acj" https://dodo.ct.comodo.com/ct/v1/add-chain
    wget -nv -O "$acj.sct.rocketeer" --post-file "$acj" https://ct.googleapis.com/rocketeer/ct/v1/add-chain
  fi
done

# Tidy up the SCT filenames.
rename add-chain.json.sct sct *.add-chain.json.sct.*

mv *.crt "$CERT_DIR/crt"
mv *_*.add-chain.json "$CERT_DIR/json"
mv *.sct.* "$CERT_DIR/sct"
