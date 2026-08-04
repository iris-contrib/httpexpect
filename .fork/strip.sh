#!/usr/bin/env bash
#
# Remove everything this fork does not ship: upstream's tests, examples and
# development tooling. Run after every upstream merge, then `go mod tidy`.
#
# This is a script rather than a stored patch because deletions cannot be
# replayed: each upstream release adds files no old patch would mention.
#
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

# Tests. Quote the glob — git's pathspec wildcard crosses '/', so this also
# catches e2e/*_test.go. An unquoted glob would be expanded by the shell first
# and would miss them.
git rm -qf  --ignore-unmatch -- '*_test.go'
git rm -rqf --ignore-unmatch -- e2e

# Examples and images.
git rm -rqf --ignore-unmatch -- _examples _images

# Upstream development tooling and docs.
git rm -qf --ignore-unmatch -- \
    HACKING.md \
    Makefile \
    AUTHORS.md \
    CHANGES.md \
    .golangci.yml \
    .ignore \
    .spelling \
    .codecov.yml

# Upstream CI, replaced by this fork's own.
git rm -rqf --ignore-unmatch -- \
    .github/FUNDING.yml \
    .github/workflows/build.yaml \
    .github/workflows/detect_conflicts.yml

echo "stripped. now run: go mod tidy"
