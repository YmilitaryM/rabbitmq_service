%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%      Copyright (C) 2019 ... All rights reserved.
%%      FileName ：rabbitmq_service.erl
%%      Create   ：Jin <ymilitarym@163.com
%%      Date     : 2019-04-26
%%      Describle: 
%%      
%%      
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-module(rabbitmq_service).
-include_lib("amqp_client/include/amqp_client.hrl").
-record(rabbitmq_server, {server = undefined}).


-behaviour(gen_server).

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2]).
-export([handle_info/2, shutdown/0,
				 terminate/2, code_change/3]).

start_link(Args) ->
		gen_server:start_link(?MODULE, Args, []).

init(Args) ->
	User = proplists:get_value(user, Args, <<"guest">>),
	Password = proplists:get_value(password, Args, <<"guest">>),
	Host = proplists:get_value(host, Args, "127.0.0.1"),
	Port = proplists:get_value(port, Args, 5672),
	{ok, Connection} = amqp_connection:start(#amqp_params_network{username = User, password = Password, host = Host, port = Port}),
 	RabbitmqServer =
 	#rabbitmq_server{
 		server = Connection
 	},
  {ok, RabbitmqServer}.

handle_cast({work, Queue, RoutingKey, PayLoad}, #rabbitmq_server{server = Connection} = State)	->
	{ok, Channel} = amqp_connection:open_channel(Connection),
	amqp_channel:call(Channel, #'queue.declare'{queue = Queue, durable = true}),
	Publish =  #'basic.publish'{exchange = <<"">>,
                        			routing_key = RoutingKey},
  Props = #'P_basic'{delivery_mode = 2},
  Msg = #'amqp_msg'{props = Props,
  									payload = PayLoad},
	amqp_channel:cast(Channel, Publish, Msg),
	amqp_channel:close(Channel),
	{noreply, State};

handle_cast({delete_work, Queue, RoutingKey, PayLoad}, #rabbitmq_server{server = Connection} = State)	->
	{ok, Channel} = amqp_connection:open_channel(Connection),
	amqp_channel:call(Channel, #'queue.declare'{queue = Queue, durable = true}),
	Publish =  #'basic.publish'{exchange = <<"">>,
                        			routing_key = RoutingKey},
  Props = #'P_basic'{delivery_mode = 2},
  Msg = #'amqp_msg'{props = Props,
  									payload = PayLoad},
	amqp_channel:cast(Channel, Publish, Msg),
	amqp_channel:close(Channel),
	{noreply, State};

handle_cast({topic, Exchange, RoutingKey, PayLoad}, #rabbitmq_server{server = Connection} = State)	->
	{ok, Channel} = amqp_connection:open_channel(Connection),
	amqp_channel:call(Channel, #'exchange.declare'{exchange = Exchange, type = <<"topic">>}),
	Publish = #'basic.publish'{exchange = Exchange, routing_key = RoutingKey},
	Msg = #'amqp_msg'{payload = PayLoad},
  amqp_channel:cast(Channel, Publish, Msg),
  amqp_channel:close(Channel),
  {noreply, State};

handle_cast({route, Exchange, RoutingKey, PayLoad}, #rabbitmq_server{server = Connection} = State)	->
	{ok, Channel} = amqp_connection:open_channel(Connection),
	amqp_channel:call(Channel, #'exchange.declare'{exchange = Exchange, type = <<"direct">>}),
	amqp_channel:cast(Channel,
                      #'basic.publish'{
                        exchange = Exchange,
                        routing_key = RoutingKey},
                      #'amqp_msg'{payload = PayLoad}),
	amqp_channel:close(Channel),
	{noreply, State};

handle_cast({sub, Exchange, RoutingKey, PayLoad}, #rabbitmq_server{server = Connection} = State)	->
	{ok, Channel} = amqp_connection:open_channel(Connection),
	amqp_channel:call(Channel, #'exchange.declare'{exchange = Exchange, type = <<"fanout">>}),
	amqp_channel:cast(Channel,
                      #'basic.publish'{
                        exchange = Exchange,
                        routing_key = RoutingKey},
                      #'amqp_msg'{payload = PayLoad}),
	amqp_channel:close(Channel),
	{noreply, State};

handle_cast(_Requset , State)	->
	{noreply, State}.


shutdown() ->
	gen_server:call(?MODULE, shutdown).

handle_call(shutdown, _From, State) ->
  {stop, normal, State};
handle_call(_Msg, _From, State) ->
    {reply, ok, State}.

handle_info(_Message, State) -> {noreply, State}.
%% Server termination
terminate(_Reason, State) ->
	Server = State#rabbitmq_server.server,
	amqp_connection:close(Server),
	ok.

%% Code change
code_change(_OldVersion, State, _Extra) -> {ok, State}.
