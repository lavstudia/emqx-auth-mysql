%% Copyright (c) 2013-2019 EMQ Technologies Co., Ltd. All Rights Reserved.
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%     http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(emqx_auth_mysql_app).

-behaviour(application).

-include("emqx_auth_mysql.hrl").

-import(emqx_auth_mysql_cli, [parse_query/1]).

%% Application callbacks
-export([start/2, prep_stop/1, stop/1]).

%%--------------------------------------------------------------------
%% Application callbacks
%%--------------------------------------------------------------------

start(_StartType, _StartArgs) ->
    {ok, Sup} = emqx_auth_mysql_sup:start_link(),
    if_enabled(auth_query, fun load_auth_hook/1),
    if_enabled(acl_query,  fun load_acl_hook/1),
    emqx_auth_mysql_cfg:register(),
    {ok, Sup}.

prep_stop(State) ->
    emqx:unhook('client.authenticate', fun emqx_auth_mysql:check/2),
    emqx:unhook('client.check_acl', fun emqx_acl_mysql:check_acl/5),
    emqx_auth_mysql_cfg:unregister(),
    State.

stop(_State) ->
    ok.

load_auth_hook(AuthQuery) ->
    SuperQuery = parse_query(application:get_env(?APP, super_query, undefined)),
    {ok, HashType} = application:get_env(?APP, password_hash),
    Params = #{auth_query  => AuthQuery,
               super_query => SuperQuery,
               hash_type   => HashType},
    emqx:hook('client.authenticate', fun emqx_auth_mysql:check/2, [Params]).

load_acl_hook(AclQuery) ->
    emqx:hook('client.acl_check', fun emqx_acl_mysql:check_acl/5, [#{acl_query => AclQuery}]).

%%--------------------------------------------------------------------
%% Internal function
%%--------------------------------------------------------------------

if_enabled(Cfg, Fun) ->
    case application:get_env(?APP, Cfg) of
        {ok, Query} -> Fun(parse_query(Query));
        undefined   -> ok
    end.
