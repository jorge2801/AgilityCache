-module(agilitycache_utils).
-export([get_app_env/2, get_app_env/3]).

get_app_env(Key, Default) ->
  get_app_env(agilitycache, Key, Default).

get_app_env(App, Key, Default) ->
  case application:get_env(App, Key) of
    undefined ->
      Default;
    {ok, undefined} ->
      Default;
    {ok, Value} ->
      Value
    end.
