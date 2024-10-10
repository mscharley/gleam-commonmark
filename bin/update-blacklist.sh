#!/usr/bin/env sh

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Intended to be used as `./bin/update-blacklist.sh >> test/commonmark_test/spec.gleam` and then
# manually cut and paste the results into the blacklist.
gleam test | grep FAIL | grep -v '(strict)' | sed -E 's/.* Example ([[:digit:]]+)/\1/' | sort -n | sed -e 's/$/,/'
