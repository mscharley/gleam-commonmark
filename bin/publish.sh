#!/usr/bin/env bash
set -e

gleam publish
cd npm
npm i
npm run build
npm publish
