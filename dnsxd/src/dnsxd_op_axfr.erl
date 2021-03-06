%% -------------------------------------------------------------------
%%
%% Copyright (c) 2011 Andrew Tunnell-Jones. All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------
-module(dnsxd_op_axfr).
-include("dnsxd_internal.hrl").

%% API
-export([handle/2]).

%%%===================================================================
%%% API
%%%===================================================================

handle(MsgCtx, #dns_message{
	 questions=[#dns_query{name = ZoneName}]} = ReqMsg) ->
    ZoneRef = dnsxd_ds_server:get_zone(ZoneName),
    Protocol = dnsxd_op_ctx:protocol(MsgCtx),
    {SrcIPTuple, SrcPort} = dnsxd_op_ctx:src(MsgCtx),
    SrcIP = dnsxd_lib:ip_to_txt(SrcIPTuple),
    Refuse = if Protocol =:= udp -> true;
		ZoneRef =:= undefined -> true;
		true ->
		     Datastore = dnsxd:datastore(),
		     not Datastore:dnsxd_allow_axfr(MsgCtx, ZoneName)
	     end,
    MsgArgs = [ZoneName, SrcIP, SrcPort],
    Props = case Refuse of
		true ->
		    ?DNSXD_INFO("Refusing AXFR of ~s to ~s:~p", MsgArgs),
		    [{rc, ?DNS_RCODE_REFUSED}];
		false ->
		    ?DNSXD_INFO("Allowing AXFR of ~s to ~s:~p", MsgArgs),
		    [{an, sets(ZoneRef)}, {dnssec, true}]
	    end,
    MsgCtx0 = dnsxd_op_ctx:tc_mode(MsgCtx, axfr),
    dnsxd_op_ctx:reply(MsgCtx0, ReqMsg, Props).

%%%===================================================================
%%% Internal functions
%%%===================================================================

sets(ZoneRef) ->
    Sets = dnsxd_ds_server:get_all_sets(ZoneRef),
    {value, SOASet, Sets0} = lists:keytake(?DNS_TYPE_SOA, #rrset.type, Sets),
    LastSOASet = SOASet#rrset{sig = []},
    [SOASet|Sets0] ++ [LastSOASet].
