defmodule Andycot.EventProcessor.Auction do 
	@moduledoc """
	"""
	require Logger
	alias Andycot.Repo
	import Andycot.Tools.Timestamp
	alias Decimal, as: D

	alias Andycot.AuctionSupervisor

	alias Andycot.FsmAuction
	alias Andycot.FsmAuctionData

	alias Andycot.CommandProcessor.AuctionData
	alias Andycot.CommandProcessor.Auction

	alias Andycot.Event.Auction.{AuctionStarted, AuctionScheduled}
	alias Andycot.Event.Auction.{BidRejected, BidPlaced}
	alias Andycot.Event.Auction.{CloseRejected, AuctionClosed}
	alias Andycot.Event.Auction.{AuctionRenewed, RenewRejected}
	alias Andycot.Event.Auction.{AuctionSuspended, SuspendRejected}
	alias Andycot.Event.Auction.{AuctionResumed, ResumeRejected}
	alias Andycot.Event.Auction.{AuctionCreated, AuctionSold}
	alias Andycot.Event.Auction.{WatchCountIncremented, WatchCountDecremented, VisitCountIncremented}

	alias Andycot.Command.Auction.{StartAuction, ScheduleAuction, PlaceBid, CloseAuction, RenewAuction, SoldAuction, SuspendAuction, ResumeAuction}
	alias Andycot.Command.Auction.{CreateAuction}

	# TODO export to a configuration file
	@seconds_to_extend 5


	@doc """
	"""
	def replay_events(fsm, auction_id) do
		Logger.info "Auction #{auction_id} replay all events"

		Repo.get_auction_events(auction_id)
		|> Enum.map(fn {event_type, event_data} -> {event_type, atom_keys(event_data)} end)
		|> replay_next_event(fsm)
	end

	@doc """
	Handles the replay of the next event
	"""
	def replay_next_event([head|tail], fsm) do
		{event_type, event_data} = head

		Logger.info("Auction #{event_data.auction_id} NEXT event to replay #{event_type}")

		{:ok, new_fsm} = replay_event(event_type, event_data, :replay, fsm)

		replay_next_event(tail, new_fsm)
	end

	@doc """
	Handles the replay of the next event
	Helps to stop the recursion when the list of events to replay is empty
	"""
	def replay_next_event([], fsm) do
		fsm
	end

	#
	# Generates functions that applies an event based on the event name
	#
	for event <- ["Elixir.Andycot.Event.Auction.AuctionStarted", 
								"Elixir.Andycot.Event.Auction.AuctionScheduled",
								"Elixir.Andycot.Event.Auction.BidPlaced",
								"Elixir.Andycot.Event.Auction.AuctionClosed",
								"Elixir.Andycot.Event.Auction.AuctionSold",
								"Elixir.Andycot.Event.Auction.AuctionRenewed",
								"Elixir.Andycot.Event.Auction.BidRejected",
								"Elixir.Andycot.Event.Auction.CloseRejected",
								"Elixir.Andycot.Event.Auction.WatchCountIncremented",
								"Elixir.Andycot.Event.Auction.WatchCountDecremented",
								"Elixir.Andycot.Event.Auction.VisitCountIncremented"
							 ] do
		def replay_event(event = event_type, event_data, mode, auction_state) do
			Logger.info("Auction #{auction_state.auction_id} Replaying event #{event_type}")
			apply_event(struct(String.to_atom(event), event_data), auction_state, mode)
		end
	end

	def replay_event(event_type, _event_data, _mode, auction_state) do
		Logger.error("Auction #{auction_state.auction_id} unhandled event #{event_type}")
		{nil, nil, auction_state}
	end

	@doc """
	Process the auction related events

	Returns : 
	{ :nack, event.reason}
	"""
	def apply_event(event, fsm, mode \\ :standard)

	def apply_event(%AuctionStarted{} = event, %FsmAuction{} = fsm, mode) do
		Logger.info("Auction #{event.auction_id}   applying event AuctionStarted")

		fsm 
		|> FsmAuction.auction_started(event, mode)
	end

	def apply_event(%AuctionScheduled{} = event, %FsmAuction{} = fsm, mode) do
		Logger.info("Auction #{event.auction_id}   applying event AuctionScheduled")

		fsm 
		|> FsmAuction.auction_scheduled(event, mode)
	end

	def apply_event(%BidPlaced{} = event, %FsmAuction{data: %FsmAuctionData{sale_type_id: 1}} = fsm, mode) do
		Logger.info("Auction #{event.auction_id}   applying event BidPlaced")

		fsm 
		|> FsmAuction.bid_placed(event, mode)
	end

	def apply_event(%BidPlaced{} = event, %FsmAuction{data: %FsmAuctionData{sale_type_id: 2}} = fsm, mode) do
		Logger.info("Auction #{event.auction_id}   applying event BidPlaced")

		new_fsm = fsm 
		|> FsmAuction.bid_placed(event, mode)

		if new_fsm.data.clone_parameters != nil do
 			cloned_fsm_data = %FsmAuctionData{new_fsm.data | 	auction_id: nil,
																												cloned_from_auction_id: new_fsm.data.auction_id,
																												stock: new_fsm.data.clone_parameters.stock, 
																												end_date_time: new_fsm.data.clone_parameters.end_date_time}

			{:ok, cloned_fsm} = AuctionSupervisor.clone_auction(struct(CreateAuction, Map.from_struct(cloned_fsm_data)))

			put_in(new_fsm.data.cloned_to_auction_id, cloned_fsm.data.auction_id)
		else
			new_fsm
		end
	end

	def apply_event(%BidRejected{} = event, %FsmAuction{} = fsm, mode) do
		Logger.info("Auction #{event.auction_id}   applying event BidRejected")

		fsm 
		|> FsmAuction.bid_rejected(event, mode)
	end

	def apply_event(%AuctionClosed{} = event, %FsmAuction{} = fsm, mode) do
		Logger.info("Auction #{event.auction_id}   applying event AuctionClosed")

		fsm 
		|> FsmAuction.auction_closed(event, mode)
	end

	def apply_event(%CloseRejected{} = event, %FsmAuction{} = fsm, mode) do
		Logger.info("Auction #{event.auction_id}   applying event CloseRejected")

		fsm 
		|> FsmAuction.close_rejected(event, mode)
	end

	def apply_event(%AuctionSold{} = event, %FsmAuction{} = fsm, mode) do
		Logger.info("Auction #{event.auction_id}   applying event AuctionSold")

		fsm 
		|> FsmAuction.auction_sold(event, mode)
	end

	def apply_event(%AuctionRenewed{} = event, %FsmAuction{} = fsm, mode) do
		Logger.info("Auction #{event.auction_id}   applying event AuctionRenewed")

		new_fsm = fsm 
		|> FsmAuction.auction_renewed(event, mode)

		if new_fsm.data.clone_parameters != nil do
 			cloned_fsm_data = %FsmAuctionData{new_fsm.data | 	auction_id: nil,
																									 			closed_by: nil,
																												cloned_from_auction_id: new_fsm.data.auction_id,
																												stock: new_fsm.data.clone_parameters.stock, 
																												start_date_time: new_fsm.data.clone_parameters.start_date_time,
																												end_date_time: new_fsm.data.clone_parameters.end_date_time}

			{:ok, cloned_fsm} = AuctionSupervisor.clone_auction(struct(CreateAuction, Map.from_struct(cloned_fsm_data)))
			put_in(new_fsm.data.cloned_to_auction_id, cloned_fsm.data.auction_id)
		else
			new_fsm
		end
	end

	def apply_event(%RenewRejected{} = event, %FsmAuction{} = fsm, mode) do
		Logger.info("Auction #{event.auction_id}   applying event RenewRejected")

		fsm 
		|> FsmAuction.renew_rejected(event, mode)
	end

	def apply_event(%AuctionSuspended{} = event, %FsmAuction{} = fsm, mode) do
		Logger.info("Auction #{event.auction_id}   applying event AuctionSuspended")

		fsm 
		|> FsmAuction.auction_suspended(event, mode)
	end

	def apply_event(%SuspendRejected{} = event, %FsmAuction{} = fsm, mode) do
		Logger.info("Auction #{event.auction_id}   applying event SuspendRejected")

		fsm 
		|> FsmAuction.suspend_rejected(event, mode)
	end

	def apply_event(%AuctionResumed{} = event, %FsmAuction{} = fsm, mode) do
		Logger.info("Auction #{event.auction_id}   applying event AuctionResumed")

		new_fsm = fsm 
		|> FsmAuction.auction_resumed(event, mode)

		if new_fsm.data.clone_parameters != nil do
 			cloned_fsm_data = %FsmAuctionData{new_fsm.data | 	auction_id: nil,
																									 			closed_by: nil,
																												cloned_from_auction_id: new_fsm.data.auction_id,
																												stock: new_fsm.data.clone_parameters.stock, 
																												start_date_time: new_fsm.data.clone_parameters.start_date_time,
																												end_date_time: new_fsm.data.clone_parameters.end_date_time}

			{:ok, cloned_fsm} = AuctionSupervisor.clone_auction(struct(CreateAuction, Map.from_struct(cloned_fsm_data)))
			put_in(new_fsm.data.cloned_to_auction_id, cloned_fsm.data.auction_id)
		else
			new_fsm
		end
	end

	def apply_event(%ResumeRejected{} = event, %FsmAuction{} = fsm, mode) do
		Logger.info("Auction #{event.auction_id}   applying event ResumeRejected")

		fsm 
		|> FsmAuction.resume_rejected(event, mode)
	end

	def apply_event(%WatchCountIncremented{} = event, %FsmAuction{} = fsm, mode) do
		Logger.info("Auction #{event.auction_id}   applying event WatchCountIncremented")

		fsm 
		|> FsmAuction.watch_count_incremented(event, mode)
	end

	def apply_event(%WatchCountDecremented{} = event, %FsmAuction{} = fsm, mode) do
		Logger.info("Auction #{event.auction_id}   applying event WatchCountDecremented")

		fsm 
		|> FsmAuction.watch_count_decremented(event, mode)
	end

	def apply_event(%VisitCountIncremented{} = event, %FsmAuction{} = fsm, mode) do
		Logger.info("Auction #{event.auction_id}   applying event VisitCountIncremented")

		fsm 
		|> FsmAuction.visit_count_incremented(event, mode)
	end

	#def apply_event(%AuctionSold{} = event, %FsmAuction{} = fsm, mode) do
	#	Logger.info("Auction #{event.auction_id}   applying event AuctionSold")
	#	new_fsm = fsm |> FsmAuction.auction_renewed(event, mode)
	#	{:ok, new_fsm}
	#end

	@doc """
	Helper function used when merging two maps where we want to keep the values of the map given as the right parameter
	"""
	def map_merge_keep_right(k, vl, vr) do
		# IO.puts "#{k} vl #{vl} vr #{vr}"
		vr || vl
	end

	@doc """
	"""
	def make_auction_started_event(%StartAuction{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(AuctionStarted, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_auction_scheduled_event(%ScheduleAuction{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(AuctionScheduled, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_auction_created_event(%CreateAuction{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(AuctionCreated, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_bid_placed_event(%PlaceBid{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(BidPlaced, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_bid_rejected_event(%PlaceBid{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(BidRejected, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_auction_closed_event(%CloseAuction{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(AuctionClosed, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_close_rejected_event(%CloseAuction{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(CloseRejected, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_auction_resumed_event(%ResumeAuction{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(AuctionResumed, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_resume_rejected_event(%ResumeAuction{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(ResumeRejected, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_auction_renewed_event(%RenewAuction{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(AuctionRenewed, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_renew_rejected_event(%RenewAuction{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(RenewRejected, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_auction_suspended_event(%SuspendAuction{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(AuctionSuspended, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_suspend_rejected_event(%SuspendAuction{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(SuspendRejected, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_auction_sold_event(%SoldAuction{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(AuctionSold, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_watch_count_incremented_event(auction_id) do
		%WatchCountIncremented{auction_id: auction_id}
	end

	@doc """
	"""
	def make_watch_count_decremented_event(auction_id) do
		%WatchCountDecremented{auction_id: auction_id}
	end

	@doc """
	"""
	def make_visit_count_incremented_event(auction_id) do
		%VisitCountIncremented{auction_id: auction_id}
	end

	@doc """
	"""
	def make_bid_from_event(%BidPlaced{} = event, overwrite \\ %{}) do
		Map.merge(event, struct(State.Bid, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def atom_keys(the_map) do
		for {key, val} <- the_map, into: %{}, do:	{String.to_atom(key), val}
	end

	@doc """
	"""
	def update_auction_state(%AuctionData{} = auction_state, new_current_price, new_bids) do
		%AuctionData{auction_state | 	current_price: new_current_price,
																	bids: List.flatten([new_bids | auction_state.bids])}
	end

	@doc """
	"""
	def maybe_extend_time(%AuctionData{time_extension: true} = auction_state) do
		{:ack, :bid_placed_time_extended, %AuctionData{auction_state | end_date_time: auction_state.end_date_time+@seconds_to_extend}}
	end

	@doc """
	"""
	def maybe_extend_time(%AuctionData{} = auction_state) do
		{:ack, :bid_placed, auction_state}
	end

	@doc """
	"""
  def add_amounts(value, bid_up) do
  	{f, _} = D.with_context(%D.Context{precision: 9, rounding: :half_up}, fn -> D.add(D.new(value), D.new(bid_up)) end)
  	|> D.to_string
  	|> Float.parse

  	f
  end

end
