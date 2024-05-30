#!/usr/bin/env sh

# Intended to be used as `./bin/update-blacklist.sh >> test/commonmark_spec.gleam` and then
# manually cut and paste the results into the blacklist.
gleam test | grep FAIL | sed -E 's/.* Example ([[:digit:]]+)/\1/' | sort -n | sed -e 's/$/,/'
