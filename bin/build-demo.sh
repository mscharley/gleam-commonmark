#!/usr/bin/env sh

# Move to the correct folder
cd demo/
set -x

# Do a build
gleam run -m lustre/dev build

# Move all the static files into place
for f in index.html build/dev/javascript/lustre_ui/priv priv; do
	mkdir -p ./out/$(dirname $f)
	cp -r ./$f ./out/$f
done
