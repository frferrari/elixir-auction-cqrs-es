defmodule Andycot.Repo do
  use Ecto.Repo, otp_app: :andycot, adapter: Mongo.Ecto

	import Ecto.Query
	import Andycot.Tools.Timestamp
	alias Andycot.Repo
	alias Andycot.CommandProcessor.AuctionData
	
	alias Andycot.Event.Auction.{AuctionCreated, AuctionStarted, AuctionScheduled}
	alias Andycot.Event.Auction.{BidRejected, BidPlaced}
	alias Andycot.Event.Auction.{CloseRejected, AuctionClosed, AuctionSuspended, SuspendRejected}
	alias Andycot.Event.Auction.{AuctionSold, AuctionRenewed, RenewRejected, AuctionResumed, ResumeRejected}
	alias Andycot.Event.Auction.{WatchCountIncremented, WatchCountDecremented}
	alias Andycot.Event.Auction.{VisitCountIncremented}

	alias Andycot.Event.User.{UserRegistered, UserUnregistered}
	alias Andycot.Event.User.{AccountActivated, AccountLocked, AccountUnlocked}
	alias Andycot.Event.User.{AuctionWatched, WatchRejected, AuctionUnwatched}

	@page_size 100

	@doc """
	Persists an event into the auction event store
	"""
	def persist_auction_event(event_type, %{} = event_data, :replay = mode) do
		Logger.info("Auction #{event_data.auction_id} event #{event_type} is not persisted in #{mode} mode")
		Andycot.Model.AuctionEvent.make_event(event_type, event_data, mode)
	end

	def persist_auction_event(event_type, %{} = event_data, mode) do
		Logger.info("Auction #{event_data.auction_id} storing event #{event_type} (#{mode})")

		event =	Andycot.Model.AuctionEvent.make_event(event_type, event_data, mode)

		try do
			event
			|> insert!

			event
		catch 
			x, y -> Logger.error("Error while persisting event")
						IO.inspect x
						IO.inspect y
						IO.inspect event
		end
	end

	@doc """
	"""
	def persist_event(%AuctionCreated{} = event, mode, _auction_state) do
		persist_auction_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%AuctionStarted{} = event, mode, _auction_state) do
		persist_auction_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%AuctionScheduled{} = event, mode, _auction_state) do
		persist_auction_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%BidRejected{} = event, mode, _auction_state) do
		persist_auction_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%BidPlaced{} = event, mode, _auction_state) do
		persist_auction_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%CloseRejected{} = event, mode, _auction_state) do
		persist_auction_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%AuctionClosed{} = event, mode, _auction_state) do
		persist_auction_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%AuctionSuspended{} = event, mode, _auction_state) do
		persist_auction_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%SuspendRejected{} = event, mode, _auction_state) do
		persist_auction_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%AuctionRenewed{} = event, mode, _auction_state) do
		persist_auction_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%RenewRejected{} = event, mode, _auction_state) do
		persist_auction_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%AuctionResumed{} = event, mode, _auction_state) do
		persist_auction_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%ResumeRejected{} = event, mode, _auction_state) do
		persist_auction_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%AuctionSold{} = event, mode, _auction_state) do
		persist_auction_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%WatchCountIncremented{} = event, mode, _auction_state) do
		persist_auction_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%WatchCountDecremented{} = event, mode, _auction_state) do
		persist_auction_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%VisitCountIncremented{} = event, mode, _auction_state) do
		persist_auction_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_auction_renewed_event(auction_id, start_date_time, end_date_time, mode \\ :standard) do
		event = %AuctionRenewed{auction_id: auction_id, 
														start_date_time: start_date_time, 
														end_date_time: end_date_time, 
														created_at: now()}
		persist_auction_event(:auction_renewed_event, Map.from_struct(event), mode)
	end

	@doc """
	auction is of type %AuctionData{}
	"""
	def persist_auction_renewed_event(auction, mode \\ :standard) do
		event = %AuctionRenewed{auction_id: auction.auction_id, 
														start_date_time: auction.start_date_time, 
														end_date_time: auction.end_date_time, 
														created_at: now()}
		persist_auction_event(:auction_renewed_event, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_auction_closed_event(%AuctionClosed{} = event, mode \\ :standard) do
		persist_auction_event(:auction_closed_event, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_auction_closed_event(%AuctionData{} = auction, closed_by, reason, mode \\ :standard) do
		event = %AuctionClosed{	auction_id: auction.auction_id, 
														closed_by: closed_by, 
														reason: reason,
														created_at: auction.end_date_time}
		persist_auction_event(:auction_closed_event, Map.from_struct(event), mode)

		# persist_auction_event(:auction_snapshot, Map.from_struct(%AuctionData{auction | ticker_ref: nil}), mode)
	end

	@doc """
	"""
	#def persist_bid_placed_event(%Event.BidPlaced{} = event, mode \\ :standard) do
	#	persist_auction_event(:bid_placed_event, Map.from_struct(event), mode)
	#end

	#def persist_bid_placed_event(%PlaceBid{} = place_bid_command, mode \\ :standard) do
	#	event = struct(BidPlaced, Map.from_struct(place_bid_command))
	#	persist_auction_event(:bid_placed_event, Map.from_struct(event), mode)	
	#end

	@doc """
	"""
	def persist_auction_created_event(%AuctionCreated{} = event, mode \\ :standard) do
		persist_auction_event(:auction_created_event, Map.from_struct(event), mode)
	end

	@doc """
	Persists an event into the auction event store
	"""
	def persist_user_event(event_type, %{} = event_data, :replay = mode) do
		Logger.info("User #{event_data.user_id}   event #{event_type} is not persisted in #{mode} mode")
		Andycot.Model.UserEvent.make_event(event_type, event_data, mode)
	end

	def persist_user_event(event_type, %{} = event_data, mode) do
		Logger.info("User #{event_data.user_id}   storing event #{event_type} (#{mode})")

		event =	Andycot.Model.UserEvent.make_event(event_type, event_data, mode)

		try do
			event
			|> insert!

			event
		catch 
			x, y -> Logger.error("Error while persisting event")
						IO.inspect x
						IO.inspect y
						IO.inspect event
		end
	end
	
	@doc """
	"""
	def persist_event(%UserRegistered{} = event, mode, _user_state) do
		persist_user_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%UserUnregistered{} = event, mode, _user_state) do
		persist_user_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%AccountActivated{} = event, mode, _user_state) do
		persist_user_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%AccountLocked{} = event, mode, _user_state) do
		persist_user_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%AccountUnlocked{} = event, mode, _user_state) do
		persist_user_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%AuctionWatched{} = event, mode, _user_state) do
		persist_user_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%WatchRejected{} = event, mode, _user_state) do
		persist_user_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	"""
	def persist_event(%AuctionUnwatched{} = event, mode, _user_state) do
		persist_user_event(event.__struct__, Map.from_struct(event), mode)
	end

	@doc """
	Get a list of Elixir.Event.AuctionCreated events given a page number
	"""
	def get_auction_created_events(page_number) do
    offset = @page_size * (page_number - 1)

		(from a in Andycot.Model.AuctionEvent, 
			select: a.event_data,
			limit: @page_size, 
			offset: ^offset, 
			where: a.event_type == "Elixir.Andycot.Event.Auction.AuctionCreated")
		|> all
	end

	@doc """
	Get a list of Elixir.Andycot.UserEventCreated events given a page number
	"""
	def get_user_created_events(page_number) do
    offset = @page_size * (page_number - 1)

		(from a in Andycot.Model.UserEvent, 
			select: a.event_data,
			limit: @page_size, 
			offset: ^offset, 
			where: a.event_type == "Elixir.Andycot.Event.User.UserRegistered")
		|> all
	end

  @doc """
  Get the last auction_id recorded in the DB

  Returns:
  0 when no auction is recorded
  """
  def get_max_auction_id() do
	  # TODO max with group_by is not yet supported by the mongodb ecto driver
		(from a in Andycot.Model.AuctionEvent,
			select: a.auction_id,
			where: a.event_type == "Elixir.Andycot.Event.Auction.AuctionCreated",
			limit: 1,
			order_by: [desc: :auction_id])
		|> one || 0
  end

  @doc """
  Get the last user_id recorded in the DB

  Returns:
  0 when no user is recorded
  """
  def get_max_user_id() do
		(from a in Andycot.Model.UserEvent,
			select: a.user_id,
			where: a.event_type == "Elixir.Andycot.Event.User.UserRegistered",
			limit: 1,
			order_by: [desc: :user_id])
		|> one || 0
  end

  @doc """
  Get a list of {event_type, event_data} given an auction_id
  """
  def get_auction_events(auction_id) do
		(from a in Andycot.Model.AuctionEvent, 
			select: {a.event_type, a.event_data},
			where: a.auction_id == ^auction_id,
			order_by: [asc: :id])
		|> all
  end

  @doc """
  Get a list of {event_type, event_data} given an user_id
  """
  def get_user_events(user_id) do
		(from a in Andycot.Model.UserEvent, 
			select: {a.event_type, a.event_data},
			where: a.user_id == ^user_id,
			order_by: [asc: :id])
		|> all
  end

	@doc """
	"""
	def get_chunk_of_auction_events(page_number) do
		Repo.get_auction_created_events(page_number)
		|> Enum.map( &(atom_keys(&1)) )
	end

  @doc """
  """
  def get_chunk_of_user_events(page_number) do
    Repo.get_user_created_events(page_number)
    |> Enum.map( &(atom_keys(&1)) )
  end

	@doc """
	Convert a map with keys expressed as strings to a map with keys expressed as atoms

	Ex: %{"area_id" => 28, "year" => 1987} becomes %{area_id: 28, year: 1987}
	"""
	def atom_keys(the_map) do
		for {key, val} <- the_map, into: %{}, do:	{String.to_atom(key), val}
	end

end
