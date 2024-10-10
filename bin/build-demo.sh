#!/usr/bin/env sh

# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Move to the correct folder
cd demo/
set -x

# Do a build
gleam run -m lustre/dev build

# Move all the static files into place
for f in index.html build/dev/javascript/prelude.mjs build/dev/javascript/gleam_stdlib build/dev/javascript/commonmark build/dev/javascript/lustre_ui/priv priv; do
	mkdir -p ./out/$(dirname $f)
	cp -r ./$f ./out/$f
done
