# backwater

**This library is not under active maintenance; if you'd like to perform
maintenance yourself, feel free to open an issue requesting access.**

[![](https://img.shields.io/hexpm/v/backwater.svg?style=flat)](https://hex.pm/packages/backwater)
[![](https://github.com/g-andrade/backwater/workflows/build/badge.svg)](https://github.com/g-andrade/backwater/actions?query=workflow%3Abuild)

### <span id="Backwater_-_Intercluster_RPC_for_Erlang_and_Elixir">Backwater - Intercluster RPC for Erlang and Elixir</span>

`backwater` allows you to call remote modules without depending on the
Erlang distribution protocol.

It's targeted at scenarios where nodes in one datacenter need to call
nodes in another datacenter, over unsecure or unstable networks.

#### <span id="Usage">Usage</span>

Run `make console` to bring up a shell. We're going to expose the
`string` module and call it remotely.

##### <span id="1._Generate_a_secret">1. Generate a secret</span>

``` erlang
Secret = crypto:strong_rand_bytes(32).
```

##### <span id="2._Start_the_server">2. Start the server</span>

``` erlang
backwater:start_clear_server(Secret, [string]).
% {ok, _ServerPid}
```

##### <span id="3._Execute_a_remote_call">3. Execute a remote call</span>

``` erlang
backwater:call({"127.0.0.1", Secret}, string, to_upper, ["hello"]).
% {ok, "HELLO"}
```

#### <span id="Details">Details</span>

`backwater` is built on top of
[cowboy](https://github.com/ninenines/cowboy) and
[hackney](https://github.com/benoitc/hackney).

##### <span id="Requirements">Requirements</span>

  - Erlang/OTP 22 or higher
  - rebar3

For Erlang/OTP 18 support, check the 1.1.x versions. For Erlang/OTP 19
support, check the 2.x, 3.0.x, 3.1.x or 3.2.x versions. For Erlang/OTP
20/21 support, check the 3.4.x versions.

##### <span id="Documentation">Documentation</span>

Documentation is hosted on [HexDocs](https://hexdocs.pm/backwater/).

##### <span id="Authentication_and_integrity">Authentication and integrity</span>

All requests and responses are authenticated and signed using a modified
version of [HTTP
signatures](https://tools.ietf.org/id/draft-cavage-http-signatures-07.txt);
nevertheless, it's **strongly** recommended to use HTTPS, as HTTP
signatures offer no protection against replay attacks - besides risking
exposure of sensitive data.

##### <span id="Exceptions">Exceptions</span>

By default, remote exceptions are returned as errors on the caller's
side. This behaviour can be tweaked using the
`rethrow_remote_exceptions` flag in `:call/5` options.

Remote stack traces are returned by default. Because they are
computationally expensive to generate, this behaviour can be can be
changed using the `return_exception_stacktraces` flag in
`:start_clear_server` / `:start_tls_server` backwater options.

##### <span id="Serialisation">Serialisation</span>

The [external term format](http://erlang.org/doc/apps/erts/erl_ext_dist)
is used for all function arguments and return values.

Because trust is assumed unless declared otherwise (like in regular
Erlang clusters), unsafe terms are decoded by default.

For function arguments, this behaviour can be tweaked through the
`decode_unsafe_terms` setting in backwater options when running
`:start_clear_server` or `:start_tls_server`.

For return values, this behaviour can be tweaked through the
`decode_unsafe_terms` setting in `:call/5` options.

##### <span id="Compression">Compression</span>

By default, both serialised function arguments and serialised return
values larger than 300 bytes are subject to attempted compression using
gzip. The actual compression result is only used if it is indeed smaller
than the original payload.

For function arguments, this threshold can be tweaked through the
`compression_threshold` setting in `:call/5` options.

For return values, this threshold can be tweaked through the
`compression_threshold` setting in backwater options when running
`:start_clear_server` or `:start_tls_server`.

##### <span id="Payload_limits">Payload limits</span>

By default, both serialised function arguments and serialised return
values larger than 8 MiB are rejected (independently of whether they're
transmitted in compressed form or not.)

For function arguments, this limit (in bytes) can be adjusted using the
`max_encoded_args_size` setting in backwater options when running
`:start_clear_server` or `:start_tls_server`.

For return values, this limit (in bytes) can be adjusted using the
`max_encoded_result_size` setting in `:call/5` options.

##### <span id="Timeouts_and_ports">Timeouts and ports</span>

The default listen port for HTTP is 8080; for HTTPS, it's 8443. This can
be adjusted on server using the `http` options, and on clients by
specifying it in `Endpoint`.

The client enforces a default connection timeout of 8s, and a receive
timeout of 5s. Either can be adjusted using either `connect_timeout` or
`recv_timeout`, respectively, in `:call/5` options.

The server enforces a default receive timeout of 5s. This can be
adjusted using the `recv_timeout` setting in backwater options, when
running `:start_clear_server` or `:start_tls_server`.

##### <span id="On_using_alternative_HTTP_clients">On using alternative HTTP clients</span>

For now, the best way to achieve this is to build requests using the
`backwater_request` module and interpret responses using the
`backwater_response` module.

#### <span id="License">License</span>

MIT License

Copyright (c) 2017-2022 Guilherme Andrade

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

-----

*Generated by EDoc*
