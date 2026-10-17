#!/bin/sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
build=${MAJORIS_BUILD_DIR:-"$repo/build"}
sdk=${CEF_ROOT:-"$repo/.cef"}
glib-compile-schemas "$repo/data"
export GSETTINGS_SCHEMA_DIR="$repo/data"
export MAJORIS_CEF_HELPER="$build/native/cef/majoris-browser-cef-subprocess"
export MAJORIS_CEF_RESOURCES="$sdk/Release"
exec "$build/src/majoris-browser" "$@"
