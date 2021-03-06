%% This file is part of AgilityCache, a web caching proxy.
%%
%% Copyright (C) 2011, 2012 Joaquim Pedro França Simão
%%
%% AgilityCache is free software: you can redistribute it and/or modify
%% it under the terms of the GNU Affero General Public License as published by
%% the Free Software Foundation, either version 3 of the License, or
%% (at your option) any later version.
%%
%% AgilityCache is distributed in the hope that it will be useful,
%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%% GNU Affero General Public License for more details.
%%
%% You should have received a copy of the GNU Affero General Public License
%% along with this program.  If not, see <http://www.gnu.org/licenses/>.

%% @doc HTTP request manipulation API.
%%
%% Almost all functions in this module return a new <em>Rep</em> variable.
%% It should always be used instead of the one used in your function call
%% because it keeps the state of the reply. It also allows AgilityCache to do
%% some lazy evaluation and cache results where possible.
-module(agilitycache_http_rep).

-export([
         status/1, version/1, string/1,
         peer/1,
         header/2, header/3, headers/1,
         content_length/1
        ]). %% Request API.

-export([
         response_head/1,
         response_head/4
        ]). %% Misc API.

-include("http.hrl").

%% Request API.

%% @doc Return the HTTP method of the request.
-spec status(#http_rep{}) -> {http_status(), #http_rep{}}.

status(Rep) ->
    {Rep#http_rep.status, Rep}.

%% @doc Return the HTTP version used for the request.
-spec version(#http_rep{}) -> {http_version(), #http_rep{}}.

version(Rep) ->
    {Rep#http_rep.version, Rep}.

-spec string(#http_rep{}) -> {iodata(), #http_rep{}}.

string(Rep) ->
    {Rep#http_rep.string, Rep}.

%% @doc Return the peer address and port number of the remote host.
-spec peer(#http_rep{}) -> {{inet:ip_address(), inet:port_number()}, #http_rep{}}.

peer(Rep = #http_rep { peer = Peer} ) ->
    {Peer, Rep}.

-spec headers(#http_rep{}) -> {http_headers(), #http_rep{}}.

headers(#http_rep{ headers = Headers} = Req) ->
    {Headers, Req}.

-spec content_length(#http_rep{}) ->
                            {undefined | non_neg_integer(), #http_rep{}}.

content_length(#http_rep{content_length=undefined} = Req) ->
    {Length, Req1} = case header('Content-Length', Req) of
                         {undefined, Req_2} ->
                             {invalid, Req_2};
                         {L1, Req_1}->
                             %% Talvez iolist_to_binary seja desnecessário,
                             %% mas é bom para manter certinho o input com iolist/iodata
                             {(catch httpd_conf:make_integer(binary_to_list(iolist_to_binary(L1)))), Req_1}
                     end,
    case Length of
        {ok, L} when is_integer(L) ->
            {L, Req1#http_rep{content_length=L}};

        _ ->
            {undefined, Req1#http_rep{content_length=invalid}}
    end;
%% estado invalid = Content-Length: -1,
%% serve para não ficar escaneando toda hora
content_length(#http_rep{content_length=invalid} = Req) ->
    {undefined, Req};
content_length(#http_rep{content_length=ContentLength} = Req) ->
    {ContentLength, Req}.

%% @equiv header(Name, Req, undefined)
-spec header(http_header(), #http_rep{})
            -> {iodata() | undefined, #http_rep{}}.

header(Name, Req) when is_atom(Name) orelse is_binary(Name) ->
    header(Name, Req, undefined).

%% @doc Return the header value for the given key, or a default if missing.
-spec header(http_header(), #http_rep{}, Default)
            -> {iodata() | Default, #http_rep{}} when Default::any().

header(Name, #http_rep{ headers = Headers} = Req, Default) when is_atom(Name) orelse is_binary(Name) ->
    case lists:keyfind(Name, 1, Headers) of
        {Name, Value} -> {Value, Req};
        false -> {Default, Req}
    end.

-spec response_head(http_version(), http_status(), http_headers(), http_headers()) -> iolist().

response_head({VMajor, VMinor}, Status, Headers, DefaultHeaders) ->
    Majorb = list_to_binary(integer_to_list(VMajor)),
    Minorb = list_to_binary(integer_to_list(VMinor)),
    StatusLine = <<"HTTP/", Majorb/binary, ".", Minorb/binary, " ", (agilitycache_http_protocol_parser:status(Status))/binary, "\r\n">>,
    Headers2 = [{agilitycache_http_protocol_parser:header_to_binary(Key), Value} || {Key, Value} <- Headers],
    lager:debug("Headers2: ~p", [Headers2]),
    Headers4 = Headers2 ++ DefaultHeaders,
    lager:debug("Headers4: ~p", [Headers4]),
    Headers5 = [<< Key/binary, ": ", Value/binary, "\r\n" >>
                    || {Key, Value} <- Headers4],
    [StatusLine, Headers5, <<"\r\n">>].
-spec response_head(#http_rep{}) -> iolist().

response_head(Rep) ->
    response_head({1, 1}, Rep#http_rep.status, Rep#http_rep.headers, []).
