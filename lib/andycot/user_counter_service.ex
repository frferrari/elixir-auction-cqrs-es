defmodule Andycot.Service.UserCounter do
	require Logger
	alias Andycot.Repo

	@doc """
	Called during the phoenix framework startup to initialize the users counter agent
	"""
	def start_link(initial_value) do
		Logger.info "Starting"
		{:ok, agent} = Agent.start_link fn -> Repo.get_max_user_id end, name: :user_counter_service
	end

	@doc """
	Returns the next user id
	"""
	def get_next() do
		Agent.get_and_update(:user_counter_service, fn(val) -> {val + 1, val + 1} end)
	end

end
