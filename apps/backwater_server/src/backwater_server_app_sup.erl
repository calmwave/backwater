-module(backwater_server_app_sup).
-behaviour(supervisor).

%% ------------------------------------------------------------------
%% API Function Exports
%% ------------------------------------------------------------------

-export([start_link/1]).
-export([start_server/2]).
-export([stop_server/1]).
-export([app_config_changed/1]).

%% ------------------------------------------------------------------
%% supervisor Function Exports
%% ------------------------------------------------------------------

-export([init/1]).

%% ------------------------------------------------------------------
%% Macro Definitions
%% ------------------------------------------------------------------

-define(SERVER, ?MODULE).
-define(CB_MODULE, ?MODULE).

%% ------------------------------------------------------------------
%% API Function Definitions
%% ------------------------------------------------------------------

start_link(Servers) ->
    supervisor:start_link({local, ?SERVER}, ?CB_MODULE, [Servers]).

start_server(Ref, Config) ->
    Child = server_child_spec({Ref, Config}),
    start_child(Child).

stop_server(Ref) ->
    stop_child({server, Ref}).

app_config_changed(Servers) ->
    UpdatedChildren =
        [cache_child_spec() | lists:map(fun server_child_spec/1, Servers)],

    UpdatedChildrenPerId =
        maps:from_list(
          [{maps:get(id, Child), Child} || Child <- UpdatedChildren]),

    % handle existing children
    HandledIds =
        lists:map(
          fun ({Id, _Type, _PidOrStatus, _Modules}) ->
                  case maps:find(Id, UpdatedChildrenPerId) of
                      {ok, UpdatedChild} ->
                          ok = update_child(UpdatedChild);
                      error ->
                          % removed
                          ok = stop_child(Id)
                  end,
                  Id
          end,
          supervisor:which_children(?SERVER)),

    % handle new children
    lists:foreach(
      fun (#{ id := Id } = Child) ->
              case lists:member(Id, HandledIds) of
                  true -> ok;
                  false -> {ok, _} = start_child(Child)
              end
      end,
      UpdatedChildren).

%% ------------------------------------------------------------------
%% supervisor Function Definitions
%% ------------------------------------------------------------------

init([Servers]) ->
    Children = 
        [cache_child_spec() | lists:map(fun server_child_spec/1, Servers)],
    {ok, {#{}, Children}}.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

cache_child_spec() ->
    backwater_cache:child_spec(cache).

server_child_spec({Ref, Config}) ->
    backwater_server_sup:child_spec({server, Ref}, Ref, Config).

start_child(Child) ->
    supervisor:start_child(?SERVER, Child).

stop_child(ChildId) ->
    case supervisor:terminate_child(?SERVER, ChildId) of
        ok ->
            supervisor:delete_child(?SERVER, ChildId);
        {error, _} = Error ->
            Error
    end.

update_child(#{ id := Id } = NewChild) ->
    case supervisor:get_childspec(?SERVER, Id) of
        {ok, ExistingChild} when ExistingChild =:= NewChild ->
            % nothing changed, leave it be
            ok;
        {ok, _ExistingChild} ->
            ok = stop_child(Id),
            start_child(NewChild);
        {error, not_found} ->
            {error, not_found}
    end.
