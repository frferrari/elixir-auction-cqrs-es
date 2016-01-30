defmodule Andycot.AuctionSupervisor do 
	use Supervisor
	import Ecto.Query
	alias Andycot.Repo
	alias Andycot.CommandProcessor.Auction
	alias Andycot.Command.Auction.{CreateAuction, StartAuction, ScheduleAuction}
	alias Andycot.Command.Auction.{PlaceBid, CloseAuction, RenewAuction, SuspendAuction, ResumeAuction}
	require Logger

	import Andycot.Tools.Timestamp

	@doc """
	This supervisor needs to be improved (spool/spawn ...)
	"""
	def start_link do
		Logger.info "Starting __MODULE__"

		case Supervisor.start_link(__MODULE__, nil, name: :auction_supervisor) do
			{:ok, _} = ok -> 
				start_all_workers
				ok
		end
	end

	@doc """
	"""
	def init(_) do
		Logger.info "Init __MODULE__"

		children = [worker(Andycot.CommandProcessor.Auction, [], [restart: :transient])]

		supervise(children, strategy: :simple_one_for_one)
	end

	@doc """
	"""
	def start_all_workers(page_number \\ 1) do
		start_chunk_of_workers(page_number, Repo.get_chunk_of_auction_events(page_number))
	end

	@doc """
	"""
	def start_chunk_of_workers(_, []) do
		Logger.info "No more auction workers to start"
	end

	@doc """
	"""
	def start_chunk_of_workers(page_number, events) do
		Logger.info "Starting auction workers for page #{page_number}"

		for event <- events do

			start_worker(event.auction_id)

		end

		next_page_number = page_number + 1
		start_chunk_of_workers(next_page_number, Repo.get_chunk_of_auction_events(next_page_number))
	end

	@doc """
	"""
	def start_worker(auction_id) do
		Logger.info("Auction #{auction_id} starting supervised worker w/o mode)")

		Supervisor.start_child(:auction_supervisor,	[auction_id])
	end

	@doc """
	Creates an auction and starts a worker for this auction,
	If the auction_id given in the command is nil then a new auction_id is allocated

	Returns the created auction
	{ :ok, %CommandProcessor.Auction.Data{} }
	"""
	def create_auction(%CreateAuction{} = command, mode \\ :standard) do

		# Automatically generate a new auction_id if the given one is empty
		new_auction_id = command.auction_id || AuctionCounterService.get_next()
		new_command = Map.put(command, :auction_id, new_auction_id)

		case start_worker(new_auction_id) do
			{:ok, pid} -> 
				if command.start_date_time > now() do
					GenServer.call(pid, {:schedule_auction, struct(ScheduleAuction, Map.from_struct(new_command)), mode})
				else
					GenServer.call(pid, {:start_auction, struct(StartAuction, Map.from_struct(new_command)), mode})
				end

			{:error, {:already_started, _}} ->
				Logger.warn("Auction #{command.auction_id} is already started/scheduled")
				{:error, :already_registered}

			{:error, reason} -> 
				Logger.warn("Auction #{command.auction_id} could not be started/scheduled #{inspect reason}")
				{:error, reason}
		end

	end

	@doc """
	Clones an auction and starts a worker for this new auction,

	Returns the created auction
	{ :ok, %CommandProcessor.Auction.Data{} }
	"""
	def clone_auction(%CreateAuction{} = command, mode \\ :standard) do
		create_auction(Map.put(command, :auction_id, nil), mode)
	end

	@doc """
	Successfull returns
	{ :ack, :bid_placed }													(for variable price auctions)
	{ :ack, :bid_placed_time_extended }						(for variable price auctions)
	{ :ack, :bid_placed_auction_will_close } 			(for fixed price auctions)

	Failed returns
	{ :nack, :auction_has_ended }
	{ :nack, :auction_is_suspended }
	{ :nack, :self_bidding }
	{ :nack, :auction_has_ended }
	{ :nack, :auction_not_yet_started }
	{ :nack, :wrong_requested_qty }
	{ :nack, :not_enough_stock }
	{ :nack, :bid_below_allowed_min }
	{ :nack, :wrong_requested_qty }								(for fixed price auctions)
	{ :nack, :wrong_bid_price }										(for fixed price auctions)
	"""
	def place_bid(%PlaceBid{} = command, mode \\ :standard) do
		GenServer.call(Auction.via_tuple(command.auction_id), {:place_bid, command, mode})
	end

	@doc """
	Returns the auction state given an auction_id
	The return type is %CommandProcessor.Auction.Data{}
	"""
	def get_auction(auction_id, as_fsm \\ false) do
		GenServer.call(Auction.via_tuple(auction_id), {:get_auction, auction_id, as_fsm})
	end

	@doc """
	Closes an auction

	Returns :
	{ :nack, :has_bids }
	{ :nack, :not_owner_or_system }	

	{ :ack, :auction_closed }
	"""
	def close_auction(%CloseAuction{} = info, :legacy = mode) do
		GenServer.call(Auction.via_tuple(info.auction_id), {:close_auction, info, mode})
	end

	@doc """
	Closes an auction

	Returns :
	{ :nack, :has_bids }
	{ :nack, :not_owner_or_system }
	"""
	def close_auction(%CloseAuction{} = info, :standard = mode) do
		GenServer.call(Auction.via_tuple(info.auction_id), {:close_auction, info, mode})
	end

	@doc """
	Suspend an auction

	Returns :
	"""
	def suspend_auction(%SuspendAuction{} = info, mode \\ :standard) do
		GenServer.call(Auction.via_tuple(info.auction_id), {:suspend_auction, info, mode})
	end

	@doc """
	Renew an auction

	Returns :
	"""
	def renew_auction(%RenewAuction{} = info, mode \\ :standard) do
		GenServer.call(Auction.via_tuple(info.auction_id), {:renew_auction, info, mode})
	end

	@doc """
	Resume an auction

	Returns :
	"""
	def resume_auction(%ResumeAuction{} = info, mode \\ :standard) do
		GenServer.call(Auction.via_tuple(info.auction_id), {:resume_auction, info, mode})
	end

	@doc """
	Increment an auction's watch count

	Returns :
	"""
	def increment_watch_count(auction_id, mode \\ :standard) do
		GenServer.cast(Auction.via_tuple(auction_id), {:increment_watch_count, auction_id, mode})
	end

	@doc """
	Decrement an auction's watch count

	Returns :
	"""
	def decrement_watch_count(auction_id, mode \\ :standard) do
		GenServer.cast(Auction.via_tuple(auction_id), {:decrement_watch_count, auction_id, mode})
	end

	@doc """
	Increment an auction's view count

	Returns :
	"""
	def increment_visit_count(auction_id, mode \\ :standard) do
		GenServer.cast(Auction.via_tuple(auction_id), {:increment_visit_count, auction_id, mode})
	end

end
