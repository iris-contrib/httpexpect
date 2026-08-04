# httpexpect

[![Go Reference](https://pkg.go.dev/badge/github.com/iris-contrib/httpexpect/v2.svg)](https://pkg.go.dev/github.com/iris-contrib/httpexpect/v2)

End-to-end HTTP and REST API testing for Go, forked from [gavv/httpexpect](https://github.com/gavv/httpexpect).

This is the assertion engine behind [`iris/v14/httptest`](https://github.com/kataras/iris/tree/main/_examples/12-testing). You almost certainly want that package rather than this one:

```go
import "github.com/kataras/iris/v14/httptest"

func TestIndex(t *testing.T) {
    app := newApp()
    e := httptest.New(t, app)

    e.GET("/").Expect().Status(httptest.StatusOK).Body().Contains("Hello")
}
```

## How this differs from upstream

**fasthttp support is removed.** `FastBinder`, `NewFastBinder` and `NewFastWebsocketDialer` do not exist here, and neither do the six libraries behind them. Iris speaks `net/http`, so every fasthttp byte was weight that every Iris test binary carried and never used.

Everything else tracks upstream. The full list of differences, the upstream version this is based on, and the procedure for the next sync are in [FORK.md](FORK.md).

The upstream [README](https://github.com/gavv/httpexpect#readme) documents the assertion API, which is unchanged here apart from the removals above.

## Versions

`main` targets Iris v14. The `v12` branch is the pre-2026 tree that Iris v12 builds against; it is frozen and receives no upstream syncs.

## License

MIT — see [LICENSE](LICENSE). Copyright Victor Gaydov and contributors, and the Iris contributors.
