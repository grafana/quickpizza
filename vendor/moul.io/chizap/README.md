# chizap

:smile: chizap

[![go.dev reference](https://img.shields.io/badge/go.dev-reference-007d9c?logo=go&logoColor=white)](https://pkg.go.dev/moul.io/chizap)
[![License](https://img.shields.io/badge/license-Apache--2.0%20%2F%20MIT-%2397ca00.svg)](https://github.com/moul/chizap/blob/main/COPYRIGHT)
[![GitHub release](https://img.shields.io/github/release/moul/chizap.svg)](https://github.com/moul/chizap/releases)
[![Docker Metrics](https://images.microbadger.com/badges/image/moul/chizap.svg)](https://microbadger.com/images/moul/chizap)
[![Made by Manfred Touron](https://img.shields.io/badge/made%20by-Manfred%20Touron-blue.svg?style=flat)](https://manfred.life/)

[![Go](https://github.com/moul/chizap/workflows/Go/badge.svg)](https://github.com/moul/chizap/actions?query=workflow%3AGo)
[![Release](https://github.com/moul/chizap/workflows/Release/badge.svg)](https://github.com/moul/chizap/actions?query=workflow%3ARelease)
[![PR](https://github.com/moul/chizap/workflows/PR/badge.svg)](https://github.com/moul/chizap/actions?query=workflow%3APR)
[![GolangCI](https://golangci.com/badges/github.com/moul/chizap.svg)](https://golangci.com/r/github.com/moul/chizap)
[![codecov](https://codecov.io/gh/moul/chizap/branch/main/graph/badge.svg)](https://codecov.io/gh/moul/chizap)
[![Go Report Card](https://goreportcard.com/badge/moul.io/chizap)](https://goreportcard.com/report/moul.io/chizap)
[![CodeFactor](https://www.codefactor.io/repository/github/moul/chizap/badge)](https://www.codefactor.io/repository/github/moul/chizap)

[![Gitpod ready-to-code](https://img.shields.io/badge/Gitpod-ready--to--code-blue?logo=gitpod)](https://gitpod.io/#https://github.com/moul/chizap)

## Example

[embedmd]:# (example_test.go /import\ / $)
```go
import (
	"github.com/go-chi/chi"
	"go.uber.org/zap"
	"moul.io/chizap"
)

func Example() {
	logger := zap.NewExample()
	r := chi.NewRouter()
	r.Use(chizap.New(logger, &chizap.Opts{
		WithReferer:   true,
		WithUserAgent: true,
	}))
}
```

## Usage

[embedmd]:# (.tmp/godoc.txt txt /FUNCTIONS/ $)
```txt
FUNCTIONS

func New(logger *zap.Logger, opts *Opts) func(next http.Handler) http.Handler
    New returns a logger middleware for chi, that implements the http.Handler
    interface.


TYPES

type Opts struct {
	// WithReferer enables logging the "Referer" HTTP header value.
	WithReferer bool

	// WithUserAgent enables logging the "User-Agent" HTTP header value.
	WithUserAgent bool
}
    Opts contains the middleware configuration.

```

## Install

### Using go

```sh
go get moul.io/chizap
```

### Releases

See https://github.com/moul/chizap/releases

## Contribute

![Contribute <3](https://raw.githubusercontent.com/moul/moul/main/contribute.gif)

I really welcome contributions.
Your input is the most precious material.
I'm well aware of that and I thank you in advance.
Everyone is encouraged to look at what they can do on their own scale;
no effort is too small.

Everything on contribution is sum up here: [CONTRIBUTING.md](./.github/CONTRIBUTING.md)

### Dev helpers

Pre-commit script for install: https://pre-commit.com

### Contributors ✨

<!-- ALL-CONTRIBUTORS-BADGE:START - Do not remove or modify this section -->
[![All Contributors](https://img.shields.io/badge/all_contributors-2-orange.svg)](#contributors)
<!-- ALL-CONTRIBUTORS-BADGE:END -->

Thanks goes to these wonderful people ([emoji key](https://allcontributors.org/docs/en/emoji-key)):

<!-- ALL-CONTRIBUTORS-LIST:START - Do not remove or modify this section -->
<!-- prettier-ignore-start -->
<!-- markdownlint-disable -->
<table>
  <tr>
    <td align="center"><a href="http://manfred.life"><img src="https://avatars1.githubusercontent.com/u/94029?v=4" width="100px;" alt=""/><br /><sub><b>Manfred Touron</b></sub></a><br /><a href="#maintenance-moul" title="Maintenance">🚧</a> <a href="https://github.com/moul/chizap/commits?author=moul" title="Documentation">📖</a> <a href="https://github.com/moul/chizap/commits?author=moul" title="Tests">⚠️</a> <a href="https://github.com/moul/chizap/commits?author=moul" title="Code">💻</a></td>
    <td align="center"><a href="https://manfred.life/moul-bot"><img src="https://avatars1.githubusercontent.com/u/41326314?v=4" width="100px;" alt=""/><br /><sub><b>moul-bot</b></sub></a><br /><a href="#maintenance-moul-bot" title="Maintenance">🚧</a></td>
  </tr>
</table>

<!-- markdownlint-enable -->
<!-- prettier-ignore-end -->
<!-- ALL-CONTRIBUTORS-LIST:END -->

This project follows the [all-contributors](https://github.com/all-contributors/all-contributors)
specification. Contributions of any kind welcome!

### Stargazers over time

[![Stargazers over time](https://starchart.cc/moul/chizap.svg)](https://starchart.cc/moul/chizap)

## License

© 2021   [Manfred Touron](https://manfred.life)

Licensed under the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0)
([`LICENSE-APACHE`](LICENSE-APACHE)) or the [MIT license](https://opensource.org/licenses/MIT)
([`LICENSE-MIT`](LICENSE-MIT)), at your option.
See the [`COPYRIGHT`](COPYRIGHT) file for more details.

`SPDX-License-Identifier: (Apache-2.0 OR MIT)`
