%% @doc HTTP protocol handler.
%%
%% The available options are:
%% <dl>
%%  <dt>dispatch</dt><dd>The dispatch list for this protocol.</dd>
%%  <dt>max_empty_lines</dt><dd>Max number of empty lines before a request.
%%   Defaults to 5.</dd>
%%  <dt>timeout</dt><dd>Time in milliseconds before an idle keep-alive
%%   connection is closed. Defaults to 5000 milliseconds.</dd>
%% </dl>
%%
%% Note that there is no need to monitor these processes when using Cowboy as
%% an application as it already supervises them under the listener supervisor.
%%
%% @see agilitycache_http_handler
-module(agilitycache_http_protocol).

-export([start_link/4]). %% API.
-export([init/4]). %% FSM.

-include("include/http.hrl").
-include_lib("eunit/include/eunit.hrl").

-record(state, {
	  http_protocol_fsm :: pid()
	 }).

%% API.

%% @doc Start an HTTP protocol process.
-spec start_link(pid(), inet:socket(), module(), any()) -> {ok, pid()}.
start_link(ListenerPid, Socket, Transport, Opts) ->
    Pid = spawn_link(?MODULE, init, [ListenerPid, Socket, Transport, Opts]),
    {ok, Pid}.

%% FSM.

%% @private
-spec init(pid(), inet:socket(), module(), any()) -> ok.
init(ListenerPid, Socket, Transport, Opts) ->
    Dispatch = proplists:get_value(dispatch, Opts, []),
    MaxEmptyLines = proplists:get_value(max_empty_lines, Opts, 5),
    Timeout = proplists:get_value(timeout, Opts, 5000),
    cowboy:accept_ack(ListenerPid),
    error_logger:info_msg("ack ok", []),
    {ok, HttpProtocolFsmPid} = agilitycache_http_protocol_fsm:start_link([
						      {max_empty_lines, MaxEmptyLines}, 
						      {timeout, Timeout},
						      {transport, Transport},
						      {dispatch, Dispatch},
						      {listener, ListenerPid},
						      {socket, Socket},
						      {transport, Transport}]),
    ok = Transport:controlling_process(Socket, HttpProtocolFsmPid),
    error_logger:info_msg("init", []), 
    start_handle_request(#state{http_protocol_fsm = HttpProtocolFsmPid}).

start_handle_request(_State = #state{http_protocol_fsm = HttpProtocolFsmPid}) ->
  error_logger:info_msg("start_handle_request", []), 
  agilitycache_http_protocol_fsm:start_handle_request(HttpProtocolFsmPid),
  error_logger:info_msg("terminado", []).


