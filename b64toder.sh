#!/bin/bash
base64 -d "$1" > "$1.der"
rm "$1"
