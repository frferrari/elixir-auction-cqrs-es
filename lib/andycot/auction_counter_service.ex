defmodule AuctionCounterService do
	require Logger
	alias Andycot.Repo

	@doc """
	Called during the phoenix framework startup to initialize the auctions counter agent
	"""
	def start_link(initial_value) do
		Logger.info "Starting"
		{:ok, agent} = Agent.start_link fn -> Repo.get_max_auction_id end, name: :auction_counter_service
	end

	@doc """
	Returns the next auction id
	"""
	def get_next() do
		Agent.get_and_update(:auction_counter_service, fn(val) -> {val + 1, val + 1} end)
	end

end
