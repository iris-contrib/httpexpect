# Fork notes

```
upstream:      github.com/gavv/httpexpect
upstream-base: v2.17.0 (caf51320bd65a5fb931baa2b1bbee1dd5f3eb9a7)
```

Keep `upstream-base` current. The next sync reads it.

## Differences from upstream

This is the whole list. Anything not mentioned here should be byte-identical to upstream, and if it isn't, that's drift worth deleting.

**1. fasthttp is gone.** The only semantic difference.

| file | removed |
|---|---|
| `binder.go` | `FastBinder`, `NewFastBinder`, `(FastBinder) RoundTrip`, `std2fast`, `fast2std`, `fastLogger`, and `connNonTLS`/`connTLS` — the last two were referenced only from `FastBinder.RoundTrip` and are dead without it |
| `websocket_dialer.go` | `NewFastWebsocketDialer`, `(*handlerConn).runFastHandler` |
| `expect.go` | fasthttp mentions in the package doc and on the `Client` / `WebsocketDialer` interfaces |
| `go.mod` | `valyala/fasthttp`, `fasthttp/websocket`, and the indirects they drag in: `andybalholm/brotli`, `klauspost/compress`, `savsgio/gotils`, `valyala/bytebufferpool` |

**2. Module identity.** `module github.com/iris-contrib/httpexpect/v2`.

Direct dependencies are pinned to what `kataras/iris/v14` already resolves, so this fork never drags Iris's graph backwards. That pushes the `go` directive to 1.25 (via `golang.org/x/net`, which `cookie_jar.go` needs for `publicsuffix`). Iris v14 requires 1.26, so this costs nothing; the `v12` branch serves anyone on an older toolchain.

**3. Docs point at Iris.** `gavv` → `iris-contrib` in the `request.go` doc examples; `expect.go`'s package doc and the README point at the Iris `_examples` tree; `LICENSE` carries the Iris copyright line alongside upstream's.

**4. No tests, examples or upstream tooling.** Removed by `.fork/strip.sh`. Re-run it after every sync rather than trying to remember the list — each upstream release adds new files no stored patch would mention (v2.17.0 alone added `AUTHORS.md`, `CHANGES.md` and `_examples/tls.go`).

**5. Own CI.** `.github/` carries `dependabot.yml`, `workflows/ci.yml` and `workflows/codeql-analysis.yml` instead of upstream's `build.yaml` / `detect_conflicts.yml` / `FUNDING.yml`. CI enforces the invariants above rather than running a test suite that doesn't exist.

**6. `.gitattributes`** forces LF. Without it, a Windows checkout under `core.autocrlf=true` makes `gofmt -l` flag every file in the tree and the CI gate becomes unusable locally.

## Deliberately *not* different

`github.com/TylerBrock/colorjson` stays, even though it arrived after the fork's previous snapshot. It is a leaf dependency used only by `formatter.go` to colorize JSON in assertion failures. `formatter.go` is the file upstream churns hardest, so forking it to save one small dependency would cost more conflict work at every sync than the dependency costs at rest.

## Syncing to a new upstream release

The fork's history is a flat sequence of imports, so `git merge-base` against upstream is useless — it resolves to a 2020-era commit and a naive `git merge` produces ~64 conflicts. Reconstruct the correct base instead. With it, the merge produces **five** content conflicts: `LICENSE`, `README.md`, `binder.go`, `go.mod`, `go.sum`.

```sh
BASE=caf51320bd65a5fb931baa2b1bbee1dd5f3eb9a7   # upstream-base, above
NEW=v2.18.0                                     # the release you're moving to

git remote add upstream https://github.com/gavv/httpexpect.git   # once
git fetch upstream --no-tags "+refs/heads/*:refs/remotes/upstream/*"
git fetch upstream --no-tags "+refs/tags/$NEW:refs/upstream-tags/$NEW"

# Synthesize a commit whose tree is today's fork and whose parent is the
# upstream commit the fork was actually cut from. This is what gives git a
# usable merge base.
DEV=$(git commit-tree HEAD^{tree} -p $BASE -m "fork deviations vs upstream@$BASE")
git checkout -b sync/$NEW $DEV
git merge refs/upstream-tags/$NEW
```

Resolve the five, `git rm` everything reported as *deleted by us* (upstream's tests and examples), then:

```sh
bash .fork/strip.sh
go mod tidy
```

`--no-tags` on the fetches is not optional. Upstream and this fork both have a `v2.3.1` on different commits, and a stray `git push --tags` afterwards would publish upstream commits under this module's version numbers — permanently, since the Go module proxy and checksum database never forget a version.

### Verifying a sync

The shipped tree has no tests, so verify *before* stripping them, and *before* renaming the module — `e2e/*_test.go` import `github.com/gavv/httpexpect/v2`, so renaming first makes Go download the real upstream module and test that instead of your tree.

1. Delete only the fasthttp-dependent tests: every `TestFastBinder_*` in `binder_test.go`, all of `e2e/fs_test.go`, and the `*Fast*` functions in `e2e/{basic,chunked,cookie,redirect,retry,tls,websocket}_test.go`.
2. `go mod tidy && go build ./... && go vet ./... && go test ./...`
3. Diff the pass list against a pristine checkout of the same upstream tag:
   `go test -v ./... | grep '^--- PASS' | sort`

The delta must be *exactly* the tests you deleted. At the v2.17.0 sync that was 400 → 384, with the 16 missing entries all named `*Fast*`. Anything else disappearing means the strip took a live code path with it.

### Gates before publishing

```sh
go build ./... && go vet ./...
gofmt -l .                        # empty
git grep -i fasthttp -- '*.go' go.mod go.sum   # empty
git grep gavv -- '*.go' go.mod                 # empty
git ls-files '*_test.go'          # empty
```

Then compile the consumer against it:

```sh
cd /path/to/iris && go mod edit -replace github.com/iris-contrib/httpexpect/v2=/path/to/this
go mod tidy && go build ./... && go vet ./...
cd _examples && go vet ./...      # _examples is invisible to ./... — Go skips _-prefixed dirs
```

### After tagging

`GOPRIVATE`/`GONOPROXY` are often set to `*` on developer machines, which means your own `go get` will not warm `proxy.golang.org` and downstream CI will 404 on the new tag. Warm it explicitly:

```sh
env GOPRIVATE= GONOPROXY= GOPROXY=https://proxy.golang.org \
    go mod download github.com/iris-contrib/httpexpect/v2@$TAG
```

Never move or reuse a tag. Published versions are immutable in the checksum database; a moved tag gives every existing consumer a checksum mismatch that cannot be fixed except by publishing a new version.
