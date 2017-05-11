#!/bin/bash
cat url_lists/*.txt | sort | uniq | xargs -L 1 ./certscraper_bg.sh
