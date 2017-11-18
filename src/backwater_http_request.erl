%% Copyright (c) 2017 Guilherme Andrade <backwater@gandrade.net>
%%
%% Permission is hereby granted, free of charge, to any person obtaining a
%% copy  of this software and associated documentation files (the "Software"),
%% to deal in the Software without restriction, including without limitation
%% the rights to use, copy, modify, merge, publish, distribute, sublicense,
%% and/or sell copies of the Software, and to permit persons to whom the
%% Software is furnished to do so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be included in
%% all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
%% IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
%% FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
%% AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
%% LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
%% FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
%% DEALINGS IN THE SOFTWARE.

-module(backwater_http_request).

-include_lib("hackney/include/hackney_lib.hrl").
-include("backwater_client.hrl").
-include("backwater_common.hrl").
-include("backwater_http_api.hrl").

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([encode/5]).                            -ignore_xref({encode,5}).
-export([encode/6]).

%% ------------------------------------------------------------------
%% Macro Definitions
%% ------------------------------------------------------------------

-define(REQUEST_ID_SIZE, 16).        % in bytes; before being encoded using base64

-ifdef(TEST).
-define(OVERRIDE_HACK(Key, Value), override_hack((Key), (Value))).
-else.
-define(OVERRIDE_HACK(Key, Value), (Value)).
-endif.

%% ------------------------------------------------------------------
%% Type Definitions
%% ------------------------------------------------------------------

-type nonempty_headers() :: [{nonempty_binary(), binary()}, ...].
-export_type([nonempty_headers/0]).

-type options() ::
        #{ compression_threshold => non_neg_integer() }.
-export_type([options/0]).

-type state() :: #{ signed_request_msg := backwater_http_signatures:signed_message() }.
-export_type([state/0]).

-type t() ::
        #{ conn_params := conn_params(),
           http_params := http_params(),
           full_url := nonempty_binary() }.
-export_type([t/0]).

-type conn_params() ::
        #{ transport := transport(),
           host := nonempty_string(),
           port := inet:port_number() }.
-export_type([conn_params/0]).

-type transport() :: hackney_tcp | hackney_ssl.
-export_type([transport/0]).

-type http_params() ::
        #{ method := nonempty_binary(),
           path := nonempty_binary(),
           headers := nonempty_headers(),
           body := binary() }.
-export_type([http_params/0]).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

-spec encode(Endpoint, Module, Function, Args, Secret) -> {Request, RequestState}
            when Endpoint :: nonempty_binary(),
                 Module :: module(),
                 Function :: atom(),
                 Args :: [term()],
                 Secret :: binary(),
                 Request :: t(),
                 RequestState :: state().

encode(Endpoint, Module, Function, Args, Secret) ->
    encode(Endpoint, Module, Function, Args, Secret, #{}).


-spec encode(Endpoint, Module, Function, Args, Secret, Options) -> {Request, RequestState}
            when Endpoint :: nonempty_binary(),
                 Module :: module(),
                 Function :: atom(),
                 Args :: [term()],
                 Secret :: binary(),
                 Options :: options(),
                 Request :: t(),
                 RequestState :: state().

encode(Endpoint, Module, Function, Args, Secret, Options) ->
    Method = ?OVERRIDE_HACK(update_method_with, ?OPAQUE_BINARY(<<"POST">>)),
    MediaType = ?OPAQUE_BINARY(<<"application/x-erlang-etf">>),
    Headers =
        ?OVERRIDE_HACK(
           {update_headers_with, before_compression},
           [{?OPAQUE_BINARY(<<"accept">>), ?OPAQUE_BINARY(<<MediaType/binary>>)},
            {?OPAQUE_BINARY(<<"accept-encoding">>), ?OPAQUE_BINARY(<<"gzip">>)},
            {?OPAQUE_BINARY(<<"content-type">>), ?OPAQUE_BINARY(<<MediaType/binary>>)}]),
    Body =
        ?OVERRIDE_HACK(
           {update_body_with, before_compression},
           backwater_media_etf:encode(Args)),
    Arity = ?OVERRIDE_HACK(update_arity_with, length(Args)),
    CompressionThreshold =
        maps:get(compression_threshold, Options, ?DEFAULT_OPT_COMPRESSION_THRESHOLD),

    Request = base_request(Endpoint, Method, Module, Function, Arity, Headers, Body),
    HttpParams = maps:get(http_params, Request),
    {UpdatedHttpParams, State} = maybe_compress(HttpParams, Secret, CompressionThreshold),
    UpdatedRequest = Request#{ http_params := UpdatedHttpParams },
    {UpdatedRequest, State}.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

-spec base_request(nonempty_binary(), nonempty_binary(), module(), atom(), arity(),
                   nonempty_headers(), nonempty_binary())
        -> t().
base_request(Endpoint, Method, Module, Function, Arity, Headers, Body) ->
    % encode full URL
    AllPathComponents =
        [iolist_to_binary(?BACKWATER_HTTP_API_BASE_ENDPOINT),
         iolist_to_binary(?BACKWATER_HTTP_API_VERSION),
         hackney_url:urlencode(atom_to_binary(Module, utf8)),
         hackney_url:urlencode(atom_to_binary(Function, utf8)),
         integer_to_binary(Arity)],
    QueryString = <<>>,
    FullUrl =
        ?OVERRIDE_HACK(update_url_with,
                       hackney_url:make_url(Endpoint, AllPathComponents, QueryString)),

    % decode full URL back into its components
    HackneyUrl = hackney_url:parse_url(FullUrl),
    ConnParams =
        #{ transport => HackneyUrl#hackney_url.transport,
           host => HackneyUrl#hackney_url.host,
           port => HackneyUrl#hackney_url.port
         },
    HttpParams =
        #{ method => Method,
           path => HackneyUrl#hackney_url.path,
           headers => Headers,
           body => Body },

    #{ conn_params => ConnParams,
       http_params => HttpParams,
       full_url => FullUrl }.

-spec maybe_compress(http_params(), binary(), non_neg_integer())
        -> {http_params(), state()}.
maybe_compress(#{ body := Body } = HttpParams, Secret, CompressionThreshold)
  when byte_size(Body) >= CompressionThreshold ->
    CompressedBody =
        ?OVERRIDE_HACK({update_body_with, before_authentication},
                       backwater_encoding_gzip:encode(Body)),
    ContentLengthHeader = content_length_header(CompressedBody),
    ContentEncodingHeader = {<<"content-encoding">>, <<"gzip">>},
    #{ headers := Headers } = HttpParams,
    UpdatedHeaders =
        ?OVERRIDE_HACK({update_headers_with, before_authentication},
                       [ContentLengthHeader, ContentEncodingHeader | Headers]),
    UpdatedHttpParams = HttpParams#{ body := CompressedBody, headers := UpdatedHeaders },
    authenticate(UpdatedHttpParams, Secret);
maybe_compress(#{ body := Body } = HttpParams, Secret, _CompressionThreshold) ->
    UpdatedBody = ?OVERRIDE_HACK({update_body_with, before_authentication}, Body),
    ContentLengthHeader = content_length_header(UpdatedBody),
    #{ headers := Headers } = HttpParams,
    UpdatedHeaders =
        ?OVERRIDE_HACK({update_headers_with, before_authentication},
                       [ContentLengthHeader | Headers]),
    UpdatedHttpParams = HttpParams#{ headers := UpdatedHeaders, body := UpdatedBody },
    authenticate(UpdatedHttpParams, Secret).

-spec authenticate(http_params(), binary())
        -> {http_params(), state()}.
authenticate(HttpParams, Secret) ->
    #{ method := Method, path := Path, headers := Headers, body := Body } = HttpParams,
    EncodedPath = hackney_url:pathencode(Path),
    SignaturesConfig = backwater_http_signatures:config(Secret),
    RequestMsg = backwater_http_signatures:new_request_msg(Method, EncodedPath, Headers),
    RequestId = base64:encode( crypto:strong_rand_bytes(?REQUEST_ID_SIZE) ),
    SignedRequestMsg = backwater_http_signatures:sign_request(SignaturesConfig, RequestMsg, Body, RequestId),
    UpdatedHeaders =
        ?OVERRIDE_HACK({update_headers_with, final},
                       backwater_http_signatures:list_real_msg_headers(SignedRequestMsg)),
    UpdatedBody =
        ?OVERRIDE_HACK({update_body_with, final}, Body),
    UpdatedHttpParams = HttpParams#{ headers := UpdatedHeaders, body := UpdatedBody },
    State = #{ signed_request_msg => SignedRequestMsg },
    {UpdatedHttpParams, State}.

content_length_header(Data) ->
    Size = byte_size(Data),
    {<<"content-length">>, integer_to_binary(Size)}.

%% ------------------------------------------------------------------
%% Common Test Helper Definitions
%% ------------------------------------------------------------------

-ifdef(TEST).
override_hack(Key, Value) ->
    case get(override) of
        #{} = Override ->
            OverrideFun = maps:get(Key, Override, fun (V) -> V end),
            OverrideFun(Value);
        undefined ->
            Value
    end.
-endif.
