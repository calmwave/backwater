%% Copyright (c) 2017-2021 Guilherme Andrade <backwater@gandrade.net>
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

-ifdef(NO_BUILTIN_NONEMPTY_BINARY).
-type nonempty_binary() :: <<_:8,_:_*8>>.
-endif.
-export_type([nonempty_binary/0]).

-define(OPAQUE_BINARY(B), <<(B)/binary>>). % don't let Dialyzer be too smart

-define(is_non_neg_integer(V), (is_integer((V)) andalso (V) >= 0)).
-define(is_timeout(V), (?is_non_neg_integer((V)) orelse (V) =:= infinity)).
