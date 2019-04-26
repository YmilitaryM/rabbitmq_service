%%%-------------------------------------------------------------------
%% @doc rabbitmq_service top level supervisor.
%% @end
%%%-------------------------------------------------------------------

-module(rabbitmq_service_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%%====================================================================
%% API functions
%%====================================================================

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%====================================================================
%% Supervisor callbacks
%%====================================================================

%% Child :: #{id => Id, start => {M, F, A}}
%% Optional keys are restart, shutdown, type, modules.
%% Before OTP 18 tuples must be used to specify a child. e.g.
%% Child :: {Id,StartFunc,Restart,Shutdown,Type,Modules}
init([]) ->
    {ok, {{one_for_one, 100, 100}, rabbitmq_specs()}}.

%%====================================================================
%% Internal functions
%%====================================================================

rabbitmq_specs()	->
		{ok, App} = application:get_application(?MODULE),
		{ok, RabbitmqServices} = application:get_env(App, services),
		[rabbitmq_spec(App, RabbitmqService) || RabbitmqService <- RabbitmqServices].

rabbitmq_spec(App, Service)	->
		{ok, Opts} = application:get_env(App, Service),
		PoolArgs = 
					[
					 {name, {local, Service}},
					 {worker_module, rabbitmq_service}
					]	++ Opts,
		poolboy:child_spec(Service, PoolArgs, PoolArgs).





