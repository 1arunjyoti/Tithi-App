# jyotish-js

**Status: not a maintained artifact.** This directory is an incomplete
TypeScript scaffold for Ashtakoot matching. `src/index.ts` re-exports models,
services, and constants that are not present in this checkout, so it does not
build or run. It is kept only as history.

Decision (October 2026): `jyotish-js` is **not** part of the `jyotish` Dart
package's public API, is **not** covered by the Flutter tests or CI, and must
not be published to npm. `package.json` sets `"private": true` to make an
accidental publish fail.

Remove this directory or split it into its own repository with a real test
suite if JavaScript compatibility matching is ever needed. Do not add new
features here while it lives inside the Flutter package.
