defmodule Andycot.CommandProcessor.Auction do 
	@moduledoc """
	A worker to manage the state and persistence of an auction using [gen_server](http://elixir-lang.org/docs/master/elixir/GenServer.html)

	It works in three different modes :

		* `:legacy` used during the migration phase (andycot v1 to v2)
		* `:replay` used when restarting the system to replay the events
		* `:standard` used during the as-asual web-site activity

	It handles and generates the following `Commands` and `Events`

		:create_auction_command				Andycot.Event.Auction.AuctionCreated
		:place_bid_command						Andycot.Event.Auction.BidPlaced
																	Andycot.Event.Auction.BidRejected
		:close_auction_command				Andycot.Event.Auction.AuctionClosed
																	Andycot.Event.Auction.CloseRejected

	The following commands can be issued for testing purposes

		Sale type 1 with automatic_renewal = true
			Autogenerate auction_id and place a bid
			Andycot.AuctionSupervisor.create_auction(%Andycot.Command.Auction.CreateAuction{seller_id: 269, sale_type_id: 1, listed_time_id: 1, start_date_time: Tools.Timestamp.now(), end_date_time: Tools.Timestamp.now()+10, start_price: 1.00, bid_up: 0.10, stock: 1}, :standard)
			Andycot.AuctionSupervisor.place_bid(%Andycot.Command.Auction.PlaceBid{auction_id: 1, bidder_id: 260, requested_qty: 1, max_value: 1.00, created_at: Tools.Timestamp.now()}, :standard)

		Sale type 1 with automatic_renewal = false and stock = 1 and reserve_price = nil
			Autogenerate auction_id and place a bid
			Andycot.AuctionSupervisor.create_auction(%Andycot.Command.Auction.CreateAuction{seller_id: 269, sale_type_id: 1, listed_time_id: 1, start_date_time: Tools.Timestamp.now(), end_date_time: Tools.Timestamp.now()+240, start_price: 1.00, bid_up: 0.10, stock: 1}, :standard)
			Andycot.AuctionSupervisor.place_bid(%Andycot.Command.Auction.PlaceBid{auction_id: 1, bidder_id: 260, requested_qty: 1, max_value: 2.00, created_at: Tools.Timestamp.now()}, :standard)
			Andycot.AuctionSupervisor.place_bid(%Andycot.Command.Auction.PlaceBid{auction_id: 1, bidder_id: 261, requested_qty: 1, max_value: 1.30, created_at: Tools.Timestamp.now()}, :standard)
			Andycot.AuctionSupervisor.place_bid(%Andycot.Command.Auction.PlaceBid{auction_id: 1, bidder_id: 260, requested_qty: 1, max_value: 3.00, created_at: Tools.Timestamp.now()}, :standard)
			Andycot.AuctionSupervisor.place_bid(%Andycot.Command.Auction.PlaceBid{auction_id: 1, bidder_id: 262, requested_qty: 1, max_value: 2.50, created_at: Tools.Timestamp.now()}, :standard)
			Andycot.AuctionSupervisor.place_bid(%Andycot.Command.Auction.PlaceBid{auction_id: 1, bidder_id: 261, requested_qty: 1, max_value: 3.00, created_at: Tools.Timestamp.now()}, :standard)

		Sale type 1 with automatic_renewal = true and stock = 4 and reserve_price = nil
			Autogenerate auction_id and place a bid
			Andycot.AuctionSupervisor.create_auction(%Andycot.Command.Auction.CreateAuction{seller_id: 269, sale_type_id: 1, listed_time_id: 1, start_date_time: Tools.Timestamp.now(), end_date_time: Tools.Timestamp.now()+20, start_price: 1.00, bid_up: 0.10, stock: 4}, :standard)
			Andycot.AuctionSupervisor.place_bid(%Andycot.Command.Auction.PlaceBid{auction_id: 1, bidder_id: 260, requested_qty: 1, max_value: 1.40, created_at: Tools.Timestamp.now()}, :standard)

		Sale type 1 with automatic_renewal = true and reserve_price not met
			Andycot.AuctionSupervisor.create_auction(%Andycot.Command.Auction.CreateAuction{seller_id: 269, sale_type_id: 1, listed_time_id: 1, start_date_time: Tools.Timestamp.now(), end_date_time: Tools.Timestamp.now()+30, start_price: 1.00, bid_up: 0.10, stock: 1, reserve_price: 2.00}, :standard)
			Andycot.AuctionSupervisor.place_bid(%Andycot.Command.Auction.PlaceBid{auction_id: 1, bidder_id: 260, requested_qty: 1, max_value: 1.80, created_at: Tools.Timestamp.now()}, :standard)
			Andycot.AuctionSupervisor.place_bid(%Andycot.Command.Auction.PlaceBid{auction_id: 1, bidder_id: 262, requested_qty: 1, max_value: 1.90, created_at: Tools.Timestamp.now()}, :standard)

		Sale type 1 with automatic_renewal = false
			Andycot.AuctionSupervisor.start_worker(%Andycot.CommandProcessor.AuctionData{auction_id: 100, seller_id: 269, sale_type_id: 1, listed_time_id: 1, closed_by: nil, start_date_time: Tools.Timestamp.now(), end_date_time: Tools.Timestamp.now()+30, is_suspended: false, start_price: 1.00, current_price: 1.00, bid_up: 0.10, stock: 1, type_id: 1, automatic_renewal: false}, :standard)

		Sale type 2 with automatic_renewal = true
			Andycot.AuctionSupervisor.create_auction(%Andycot.Command.Auction.CreateAuction{seller_id: 269, sale_type_id: 2, listed_time_id: 1, start_date_time: Tools.Timestamp.now(), end_date_time: Tools.Timestamp.now()+10, start_price: 1.00, bid_up: 0.10, stock: 1}, :standard)
			Andycot.AuctionSupervisor.place_bid(%Andycot.Command.Auction.PlaceBid{auction_id: 1, bidder_id: 260, requested_qty: 1, max_value: 1.00, created_at: Tools.Timestamp.now()}, :standard)

		Sale type 2 with automatic_renewal = false
			Andycot.AuctionSupervisor.start_worker(%Andycot.CommandProcessor.AuctionData{auction_id: 100, seller_id: 269, sale_type_id: 2, listed_time_id: 1, closed_by: nil, start_date_time: Tools.Timestamp.now(), end_date_time: Tools.Timestamp.now()+30, is_suspended: false, start_price: 1.00, current_price: 1.00, bid_up: 0.10, stock: 10, automatic_renewal: false, type_id: 1}, :standard)

	"""

	use GenServer
	use ExActor.GenServer

	import Andycot.Tools.Timestamp
	import Andycot.EventProcessor.Auction

	alias Andycot.Model.UserEvent

	alias Andycot.AuctionSupervisor
	alias Andycot.UserSupervisor

	alias Andycot.CommandProcessor.AuctionData

	alias Andycot.FsmAuction
	alias Andycot.FsmAuctionData

	alias Andycot.Command.Auction.{StartAuction, ScheduleAuction, PlaceBid, CloseAuction, RenewAuction, SoldAuction, SuspendAuction, ResumeAuction}
	alias Andycot.Command.Auction.{CreateAuction}

	alias Decimal, as: D
	require Logger

	defstart start_link(auction_id), gen_server_opts: [name: via_tuple(auction_id)] do

		hibernate

		FsmAuction.new
		|> replay_events(auction_id)
		|> initial_state

	end

	@doc """
	"""
	defcall start_auction(%StartAuction{} = command, mode), state: fsm do
		Logger.info("Auction #{command.auction_id} Start an auction")

		updated_command = if command.created_at == nil do
			%StartAuction{command | created_at: now()}
		else
			command
		end

		end_date_time = command.end_date_time || compute_end_date_time(command.start_date_time, command.listed_time_id)

		new_fsm = make_auction_started_event(updated_command, %{ 	original_stock: command.stock,
																															closed_by: nil,
																															suspended_at: nil,
																															created_at: now(),
																															current_price: command.start_price,
																															end_date_time: end_date_time})
		|> apply_event(fsm, mode)
		|> start_ticker

		set_and_reply(new_fsm, {:ok, new_fsm})
	end

	@doc """
	"""
	defcall schedule_auction(%ScheduleAuction{} = command, mode), state: fsm do
		Logger.info("Auction #{command.auction_id} Schedule an auction")

		updated_command = if command.created_at == nil do
			%ScheduleAuction{command | created_at: now()}
		else
			command
		end

		end_date_time = command.end_date_time || compute_end_date_time(command.start_date_time, command.listed_time_id)

		new_fsm = make_auction_scheduled_event(updated_command, %{ 	original_stock: command.stock,
																																closed_by: nil,
																																suspended_at: nil,
																																created_at: now(),
																																current_price: command.start_price,
																																end_date_time: end_date_time})
		|> apply_event(fsm, mode)
		|> start_ticker

		set_and_reply(new_fsm, {:ok, new_fsm})
	end

	@doc """
	"""
	defcall place_bid(%PlaceBid{} = command, mode), state: %FsmAuction{data: %FsmAuctionData{sale_type_id: 1, bids: []}} = fsm do
		Logger.info("Auction #{command.auction_id} Place a bid")

		normalized_command = command
		|> normalize_command(fsm.data.bid_up)

		{status, event} = cond do

			fsm.state == :scheduled ->
				# Bidding on an auction that has not started is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :auction_not_yet_started})}

			fsm.state == :suspended ->
				# Bidding on a suspended auction is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :auction_is_suspended})}

			fsm.state != :started ->
				# Bidding on an auction whose state is not :started is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :auction_state_mismatch})}

			normalized_command.bidder_id == fsm.data.seller_id ->
				# Bidding on your own auctions is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :self_bidding})}

			UserSupervisor.can_receive_bids?(fsm.data.seller_id, mode) == false ->
				# Bidding on an auction whose owner is locked in not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :seller_locked})}

			UserSupervisor.can_bid?(normalized_command.bidder_id, mode) == false ->
				# Is the bidder allowed to bid ?
				{:error, make_bid_rejected_event(normalized_command, %{reason: :bidder_locked})}

			normalized_command.created_at > fsm.data.end_date_time -> 
				# Bidding after the end time of an auction is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :auction_has_ended})}

			normalized_command.created_at < fsm.data.start_date_time -> 
				# Bidding on an auction that has not started is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :auction_not_yet_started})}

			normalized_command.requested_qty != 1 ->
				# Bidding with an erroneous qty is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :wrong_requested_qty})}

			fsm.data.stock < 1 ->
				# Bidding for too many auctions is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :not_enough_stock})}

			normalized_command.max_value < fsm.data.current_price ->
				# Bidding below the minimum price is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :bid_below_allowed_min})}

			true ->
				{:ok, make_bid_placed_event(normalized_command, %{})}

		end
		
		new_fsm = apply_event(event, fsm, mode)
		|> maybe_restart_ticker

		set_and_reply(new_fsm, {status, event, new_fsm})
	end

	@doc """
	"""
	defcall place_bid(%PlaceBid{} = command, mode), state: %FsmAuction{data: %FsmAuctionData{sale_type_id: 1, bids: [_h|_t]}} = fsm do
		Logger.info("Auction #{command.auction_id} Place a bid")

		normalized_command = command
		|> normalize_command(fsm.data.bid_up)

		{status, event} = cond do

			fsm.state == :scheduled ->
				# Bidding on an auction that has not started is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :auction_not_yet_started})}

			fsm.state == :suspended ->
				# Bidding on a suspended auction is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :auction_is_suspended})}

			fsm.state != :started ->
				# Bidding on an auction whose state is not :started is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :auction_state_mismatch})}

			normalized_command.bidder_id == fsm.data.seller_id ->
				# Bidding on your own auctions is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :self_bidding})}

			UserSupervisor.can_receive_bids?(fsm.data.seller_id, mode) == false ->
				# Bidding on an auction whose owner is locked in not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :seller_locked})}

			UserSupervisor.can_bid?(normalized_command.bidder_id, mode) == false ->
				# Is the bidder allowed to bid ?
				{:error, make_bid_rejected_event(normalized_command, %{reason: :bidder_locked})}

			normalized_command.created_at > fsm.data.end_date_time -> 
				# Bidding after the end time of an auction is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :auction_has_ended})}

			normalized_command.created_at < fsm.data.start_date_time -> 
				# Bidding on an auction that has not started is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :auction_not_yet_started})}

			normalized_command.requested_qty != 1 ->
				# Bidding with an erroneous qty is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :wrong_requested_qty})}

			fsm.data.stock < 1 ->
				# Bidding for too many auctions is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :not_enough_stock})}

			normalized_command.max_value <= fsm.data.current_price ->
				# Bidding below the minimum price is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :bid_below_allowed_min})}

			true ->
				{:ok, make_bid_placed_event(normalized_command, %{})}

		end
		
		new_fsm = apply_event(event, fsm, mode)
		|> maybe_restart_ticker

		set_and_reply(new_fsm, {status, event, new_fsm})
	end

	@doc """
	"""
	defcall place_bid(%PlaceBid{} = command, mode), state: %FsmAuction{data: %FsmAuctionData{sale_type_id: 2}} = fsm do
		Logger.info("Auction #{command.auction_id} Place a bid")

		normalized_command = command
		|> normalize_command(fsm.data.bid_up)

		{status, event} = cond do

			fsm.state == :scheduled ->
				# Bidding on an auction that has not started is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :auction_not_yet_started})}

			fsm.state == :suspended ->
				# Bidding on a suspended auction is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :auction_is_suspended})}

			fsm.state != :started ->
				# Bidding on an auction whose state is not :started is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :auction_state_mismatch})}

			normalized_command.bidder_id == fsm.data.seller_id ->
				# Bidding on your own auctions is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :self_bidding})}

			UserSupervisor.can_receive_bids?(fsm.data.seller_id, mode) == false ->
				# Bidding on an auction whose owner is locked in not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :seller_locked})}

			UserSupervisor.can_bid?(normalized_command.bidder_id, mode) == false ->
				# Is the bidder allowed to bid ?
				{:error, make_bid_rejected_event(normalized_command, %{reason: :bidder_locked})}

			normalized_command.created_at > fsm.data.end_date_time -> 
				# Bidding after the end time of an auction is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :auction_has_ended})}

			normalized_command.created_at < fsm.data.start_date_time -> 
				# Bidding on an auction that has not started is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :auction_not_yet_started})}

			normalized_command.requested_qty > fsm.data.stock ->
				# Bidding for too many auctions is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :not_enough_stock})}

			normalized_command.requested_qty <= 0 ->
				# Bidding with an erroneous qty is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :wrong_requested_qty})}

			normalized_command.max_value != fsm.data.current_price ->
				# Bidding with a price that is not equal to the auction price is not allowed
				{:error, make_bid_rejected_event(normalized_command, %{reason: :wrong_bid_price})}

			true ->
				{:ok, make_bid_placed_event(normalized_command, %{})}

		end

		bid_placed_fsm = apply_event(event, fsm, mode)

		case status do

			:error ->
				set_and_reply(bid_placed_fsm, {status, event, bid_placed_fsm})

			:ok ->
				new_fsm = %SoldAuction{	auction_id: bid_placed_fsm.data.auction_id,
																sold_to: normalized_command.bidder_id,
																sold_qty: normalized_command.requested_qty,
																price: bid_placed_fsm.data.current_price,
																currency: bid_placed_fsm.data.currency,
																created_at: event.created_at}
				|> make_auction_sold_event
				|> apply_event(bid_placed_fsm)

				set_and_reply(new_fsm, {status, event, new_fsm}, :hibernate)
		end

	end

	@doc """
	Handler for the close_auction command. An auction might be closed from the started or scheduled state only.
	Only the auction's owner ot the system users are allowed to close an auction.
	Restrictions applies, i.e. an auction might not be closed when holding bids or during the last N minutes
	before the auction's end.
	"""
	defcall close_auction(%CloseAuction{} = command, mode), state: fsm do
		Logger.info("Auction #{command.auction_id} Closing an auction")

		{status, event} = cond do

			fsm.state == :sold ->
				# Closing an already sold auction is not allowed
				{:error, make_close_rejected_event(command, %{reason: :is_already_sold})}

			fsm.state == :closed ->
				# Closing an already closed auction is not allowed
				{:error, make_close_rejected_event(command, %{reason: :is_already_closed})}

			length(fsm.data.bids) > 0 ->
				# Closing an auction who holds bids is not allowed
				{:error, make_close_rejected_event(command, %{reason: :has_bids})}

			command.closed_by == UserEvent.get_closed_by_system ->
				# The 'system' is allowed to close
				{:ok, make_auction_closed_event(command, %{})}

			can_be_ended_early?(fsm) == false ->
				# Closing an auction too close from the auction's end is not allowed
				{:error, make_close_rejected_event(command, %{reason: :too_late})}

			command.closed_by == fsm.data.seller_id ->
				# The seller is allowed to close its auctions
				{:ok, make_auction_closed_event(command, %{})}

			true ->
				{:error, make_close_rejected_event(command, %{reason: :not_owner_or_system})}

		end

		new_fsm = apply_event(event, fsm, mode)
		|> stop_ticker

		set_and_reply(new_fsm, {status, event, new_fsm})

	end

	@doc """
	Handler for the suspend_auction command. An auction might be suspended from the started or scheduled state only.
	Only the system users are allowed to suspend an auction.
	"""
	defcall suspend_auction(%SuspendAuction{} = command, mode), state: fsm do
		Logger.info("Auction #{command.auction_id} Suspending an auction")

		{status, event} = cond do

			fsm.state != :started and fsm.state != :scheduled ->
				{:error, make_suspend_rejected_event(command, %{reason: :not_started_or_scheduled})}

			command.suspended_by == UserEvent.get_suspended_by_system ->
				{:ok, make_auction_suspended_event(command, %{})}

			true ->
				{:error, make_suspend_rejected_event(command, %{reason: :not_allowed})}

		end

		new_fsm = case status do

			:error ->
				apply_event(event, fsm, mode)

			:ok ->
				apply_event(event,fsm, mode)
				|> stop_ticker

		end

		set_and_reply(new_fsm, {status, event, new_fsm})

	end

	@doc """
	Handler for the renew_auction command. An auction might be renewed from the closed state only.
	Only the auction's owner and the system users are allowed to renew an auction.
	An auction might be cloNed to be renewed.
	"""
	defcall renew_auction(%RenewAuction{} = command, mode), state: fsm do
		Logger.info("Auction #{command.auction_id} Renewing an auction")

		new_created_at 			= command.created_at || now()
		new_start_date_time = command.start_date_time || new_created_at
		new_end_date_time 	= command.end_date_time || compute_end_date_time(new_start_date_time, fsm.data.listed_time_id)

		updated_command 		= %RenewAuction{command | created_at: new_created_at, 
																									start_date_time: new_start_date_time, 
																									end_date_time: new_end_date_time}

		{status, updated_fsm, event} = cond do

			fsm.state != :closed ->
				# An auction can be renewed only if it is :closed (but not :sold)
				{:error, fsm, make_renew_rejected_event(updated_command, %{reason: :not_closed})}

			can_be_renewed_by?(fsm, updated_command.renewed_by) == false ->
				{:error, fsm, make_renew_rejected_event(updated_command, %{reason: :not_allowed})}

			fsm.data.cloned_to_auction_id != nil ->
				# An auction can be renewed only one time
				{:error, fsm, make_renew_rejected_event(updated_command, %{reason: :already_renewed})}

			true ->
				# The auction will be renewed and maybe cloNed
				{:ok, fsm, make_auction_renewed_event(updated_command)}

		end

		new_fsm = apply_event(event, updated_fsm, mode)
		|> start_ticker

		set_and_reply(new_fsm, {status, event, new_fsm})

	end

	@doc """
	Handler for the resume_auction command. An auction might be resumed from the suspended state only.
	Only the auction's owner and the system users are allowed to resume an auction.
	"""
	defcall resume_auction(%ResumeAuction{} = command, mode), state: fsm do
		Logger.info("Auction #{command.auction_id} Resuming an auction")

		new_created_at 			= command.created_at || now()
		new_start_date_time = command.start_date_time || new_created_at
		new_end_date_time 	= command.end_date_time || compute_end_date_time(new_start_date_time, fsm.data.listed_time_id)

		updated_command = %ResumeAuction{command | created_at: new_created_at, start_date_time: new_start_date_time, end_date_time: new_end_date_time}

		{status, event} = cond do

			fsm.state != :suspended ->
				{:error, make_resume_rejected_event(updated_command, %{reason: :not_suspended})}

			updated_command.resumed_by == UserEvent.get_resumed_by_system ->
				{:ok, make_auction_resumed_event(updated_command, %{})}

			updated_command.resumed_by == fsm.data.seller_id ->
				{:ok, make_auction_resumed_event(updated_command, %{})}

			true ->
				{:error, make_resume_rejected_event(updated_command, %{reason: :not_owner_or_system})}

		end

		new_fsm = case status do
			
			:error -> 
				apply_event(event, fsm, mode)

			:ok ->
				apply_event(event, fsm, mode)
				|> start_ticker

		end

		set_and_reply(new_fsm, {status, event, new_fsm})

	end

	@doc """
	Handler for the scheduling_auction_ticker timer. This timer is used to change the
	auction's state from :scheduled to :started and can only be received while in the
	:scheduled state.
	"""
	defhandleinfo :scheduling_auction_ticker, state: %FsmAuction{state: :scheduled} = fsm do

		Logger.info("Auction #{fsm.data.auction_id} Processing scheduling_auction_ticker")

		make_auction_started_event(struct(StartAuction, Map.from_struct(fsm.data)))
		|> apply_event(fsm)
		|> start_ticker
		|> maybe_new_state_hibernate

	end

	defhandleinfo :scheduling_auction_ticker, state: fsm do

		Logger.error("Auction #{fsm.data.auction_id} scheduling_auction_ticker received while in state #{fsm.state}")
		IO.inspect fsm
		noreply

	end

	@doc """
	Handler for the closing_auction_ticker timer. This timer is fired when the auction's end_date_time happens.
	It is used to change the auction's state from started to close or sold based on different conditions, mainly
	whether or not there are bids placed on the auction.
	"""
	defhandleinfo :closing_auction_ticker, state: %FsmAuction{data: %FsmAuctionData{sale_type_id: 1, bids: []}} = fsm do
		Logger.info("Auction #{fsm.data.auction_id} Handling the closing_auction_ticker (VP/no bids)")

		cond do

			fsm.state != :started ->
				Logger.error("Auction #{fsm.data.auction_id} closing_auction_ticker received while in state #{fsm.state}")
				noreply

			fsm.data.end_date_time > now() ->
				# The auction has not ended so we restart the ticker
				fsm 
				|> start_ticker
				|> maybe_new_state_hibernate

			fsm.data.automatic_renewal == true ->
				# The auction has ended without any bid and it has the automatic renewal option, so we renew this auction
				new_start_date_time = now()
				new_end_date_time = new_start_date_time + get_days_given_listed_time_id(fsm.data.listed_time_id) * (60 * 60 * 24)

				%RenewAuction{auction_id: fsm.data.auction_id, 
											renewed_by: UserEvent.get_renewed_by_system,
											start_date_time: new_start_date_time,
											end_date_time: new_end_date_time,
											created_at: new_start_date_time}
				|> make_auction_renewed_event
				|> apply_event(fsm)
				|> start_ticker
				|> maybe_new_state_hibernate

			true ->
				# The auction has ended without any bid and it doesn't have the automatic renewal option, so we close this auction
				%CloseAuction{auction_id: fsm.data.auction_id,
											closed_by: UserEvent.get_closed_by_system,
											reason: :auction_closed_no_bids_no_automatic_renewal,
											created_at: now()}
				|> make_auction_closed_event
				|> apply_event(fsm)
				|> new_state

		end

	end

	@doc """
	"""
	defhandleinfo :closing_auction_ticker, state: %FsmAuction{data: %FsmAuctionData{sale_type_id: 1, bids: [_h|_t]}} = fsm do
		Logger.info("Auction #{fsm.data.auction_id} Handling the closing_auction_ticker (VP/w/bids)")

		now = now()
		highest_bid = hd(fsm.data.bids)

		# TODO For duplicated auctions, it is required to duplicate the picture files otherwise any modification on a picture
		# file of the duplicated auction will also be visible on the original auction
		
		cond do

			fsm.state != :started ->
				Logger.error("Auction #{fsm.data.auction_id} closing_auction_ticker received while in state #{fsm.state}")
				noreply

			fsm.data.end_date_time > now ->
				# The auction has not ended so we restart the ticker
				fsm 
				|> start_ticker
				|> maybe_new_state_hibernate

			fsm.data.reserve_price == nil ->
				# The current auction is closed and marked as sold, its stock falls to 0 and its original stock is 1
				new_fsm = if fsm.data.stock > 1 do
					# A duplicate auction command is returned for an auction with a stock equal to the current auction stock - 1
					clone_auction_start_date_time = now
					clone_auction_end_date_time = compute_end_date_time(clone_auction_start_date_time, fsm.data.listed_time_id)
					clone_auction_command = struct(	CreateAuction, 
																							Map.merge(Map.from_struct(fsm.data), 
																												%{auction_id: nil,
																													cloned_from_auction_id: fsm.data.auction_id,
																													stock: fsm.data.stock-1,
																													start_date_time: clone_auction_start_date_time,
																													end_date_time: clone_auction_end_date_time},
																												&map_merge_keep_right/3)
																						)
					{:ok, cloned_auction_fsm} = AuctionSupervisor.clone_auction(clone_auction_command)
					put_in(fsm.data.cloned_to_auction_id, cloned_auction_fsm.data.auction_id)
				else
					fsm
				end

				%SoldAuction{	auction_id: fsm.data.auction_id,
											sold_to: highest_bid.bidder_id,
											sold_qty: 1,
											price: fsm.data.current_price,
											currency: fsm.data.currency,
											created_at: now()}
				|> make_auction_sold_event
				|> apply_event(new_fsm)
				|> new_state(:hibernate)
	
			highest_bid.value >= fsm.data.reserve_price ->
				# The current auction is closed and marked as sold, its stock falls to 0 and its original stock is 1
				new_fsm = if fsm.data.stock > 1 do
					# A clone auction is created with a stock equal to the current auction stock - 1
					clone_auction_start_date_time = now
					clone_auction_end_date_time = compute_end_date_time(clone_auction_start_date_time, fsm.data.listed_time_id)
					clone_auction_command = struct(	CreateAuction, 
																					Map.merge(Map.from_struct(fsm.data), 
																										%{auction_id: nil,
																											cloned_from_auction_id: fsm.data.auction_id,
																											stock: fsm.data.stock-1,
																											start_date_time: clone_auction_start_date_time,
																											end_date_time: clone_auction_end_date_time},
																										&map_merge_keep_right/3)
																				)
					{:ok, cloned_auction_fsm} = AuctionSupervisor.clone_auction(clone_auction_command)
					put_in(fsm.data.cloned_to_auction_id, cloned_auction_fsm.data.auction_id)
				else
					fsm
				end

				%SoldAuction{	auction_id: fsm.data.auction_id,
											sold_to: highest_bid.bidder_id,
											sold_qty: 1,
											price: fsm.data.current_price,
											currency: fsm.data.currency,
											created_at: now()}
				|> make_auction_sold_event
				|> apply_event(new_fsm)
				|> new_state(:hibernate)

			fsm.data.automatic_renewal == true ->
				# The current auction is closed but not sold because the bid price was lower than the reserve price
				# A clone auction is created with a stock equal to the current auction stock
				# This allows us to keep track of the list of bids that did not met the reserve price
				clone_auction_start_date_time = now
				clone_auction_end_date_time = compute_end_date_time(clone_auction_start_date_time, fsm.data.listed_time_id)
				clone_auction_command = struct(	CreateAuction, 
																						Map.merge(Map.from_struct(fsm.data), 
																											%{auction_id: nil,
																												cloned_from_auction_id: fsm.data.auction_id,
																												renewal_count: fsm.data.renewal_count+1,
																												start_date_time: clone_auction_start_date_time,
																												end_date_time: clone_auction_end_date_time},
																											&map_merge_keep_right/3)
																					)
				{:ok, cloned_auction_fsm} = AuctionSupervisor.clone_auction(clone_auction_command)
				new_fsm = put_in(fsm.data.cloned_to_auction_id, cloned_auction_fsm.data.auction_id)

				# TODO Create a sale
				# TODO Send an email to both the buyer and the seller
				# TODO Compute the new quote if matched_id is filled
				%CloseAuction{auction_id: fsm.data.auction_id,
											closed_by: UserEvent.get_closed_by_system,
											reason: :auction_closed_reserve_price_not_met,
											created_at: now()}
				|> make_auction_closed_event
				|> apply_event(new_fsm)
				|> clear_ticker
				|> new_state(:hibernate)

			true ->
				# The current auction is closed but not sold because the bid price was lower than the reserve price
				%CloseAuction{auction_id: fsm.data.auction_id,
											closed_by: UserEvent.get_closed_by_system,
											reason: :auction_closed_reserve_price_not_met,
											created_at: now()}
				|> make_auction_closed_event
				|> apply_event(fsm)
				|> new_state(:hibernate)

		end

	end

	@doc """
	"""
	defhandleinfo :closing_auction_ticker, state: %FsmAuction{data: %FsmAuctionData{sale_type_id: 2}} = fsm do
		Logger.info("Auction #{fsm.data.auction_id} Handling the closing_auction_ticker (FP)")

		cond do

			fsm.state != :started ->
				Logger.error("Auction #{fsm.data.auction_id} closing_auction_ticker received while in state #{fsm.state}")
				noreply

			fsm.data.end_date_time > now() ->
				# The auction has not ended so we restart the ticker
				fsm 
				|> start_ticker
				|> maybe_new_state_hibernate

			fsm.data.stock == 0 ->
				# The auction is sold
				sold_to = hd(fsm.data.bids).bidder_id
				sold_qty = hd(fsm.data.bids).requested_qty

				%SoldAuction{	auction_id: fsm.data.auction_id,
											sold_to: sold_to,
											sold_qty: sold_qty,
											price: fsm.data.current_price,
											currency: fsm.data.currency,
											created_at: now()}
				|> make_auction_sold_event
				|> apply_event(fsm)
				|> new_state(:hibernate)

			fsm.data.automatic_renewal == true ->
				# The auction has ended without any bid and it has the automatic renewal option, so we renew this auction
				new_start_date_time = now()
				new_end_date_time = new_start_date_time + get_days_given_listed_time_id(fsm.data.listed_time_id) * (60 * 60 * 24)

				%RenewAuction{auction_id: fsm.data.auction_id, 
											renewed_by: UserEvent.get_renewed_by_system,
											start_date_time: new_start_date_time,
											end_date_time: new_end_date_time,
											created_at: new_start_date_time}
				|> make_auction_renewed_event
				|> apply_event(fsm)
				|> start_ticker
				|> maybe_new_state_hibernate

			true ->
				# The auction has ended without any bid and it doesn't have the automatic renewal option, so we close this auction
				%CloseAuction{auction_id: fsm.data.auction_id,
											closed_by: UserEvent.get_closed_by_system,
											reason: :auction_closed_no_bids_no_automatic_renewal,
											created_at: now()}
				|> make_auction_closed_event
				|> apply_event(fsm)
				|> new_state(:hibernate)

		end

	end

	@doc """
	"""
	defcast increment_watch_count(auction_id, mode), state: fsm do
		Logger.info("Auction #{auction_id} Increment the watch_count")

		make_watch_count_incremented_event(auction_id)
		|> apply_event(fsm)
		|> new_state
	end

	@doc """
	"""
	defcast decrement_watch_count(auction_id, mode), state: fsm do
		Logger.info("Auction #{auction_id} Decrement the watch count")

		make_watch_count_decremented_event(auction_id)
		|> apply_event(fsm)
		|> new_state
	end

	@doc """
	"""
	defcast increment_visit_count(auction_id, mode), state: fsm do
		Logger.info("Auction #{auction_id} Increment the visit count")

		make_visit_count_incremented_event(auction_id)
		|> apply_event(fsm)
		|> new_state
	end

	@doc """
	"""
	defcall get_auction(auction_id, as_fsm), state: fsm do
		Logger.info("Auction #{auction_id} Get an auction")

		if as_fsm == true do
			reply({:ok, fsm})
		else
			reply({:ok, fsm.data})
		end
	end

	@doc """
	Most of the time an auction might be hibernated, but not when in the :started state and when
	running its last hour life-time.
	"""
	def maybe_new_state_hibernate(%FsmAuction{} = fsm) do
		remaining_seconds = fsm.data.end_date_time - now()

		if fsm.state == :started and remaining_seconds < 3600 do
			fsm
			|> new_state
		else
			fsm
			|> new_state(:hibernate)
		end
	end

	@doc """
	An auction can be ended early only when not holding bids and not during its last 12 hours.
	"""
	def can_be_ended_early?(%FsmAuction{data: %FsmAuctionData{sale_type_id: 1, bids: []}}) do
		true
	end

	@doc """
	"""
	def can_be_ended_early?(%FsmAuction{data: %FsmAuctionData{sale_type_id: 1, bids: [_h|_t]}} = fsm) do
		# An auction having bids cannot be ended early during its last 12 hours
		if fsm.data.end_date_time - now() < 60*60*12 do
			false
		else
			true
		end
	end

	@doc """
	"""
	def can_be_ended_early?(%FsmAuction{data: %FsmAuctionData{sale_type_id: 2}}) do
		true
	end

	@doc """
	Checks if an auction can be renewed by a given user_id
	"""
	def can_be_renewed_by?(%FsmAuction{} = fsm, renewed_by) do
		cond do
			renewed_by == UserEvent.get_renewed_by_system ->
				true

			renewed_by == fsm.data.seller_id ->
				true

			UserSupervisor.is_super_admin?(renewed_by) ->
				true

			true ->
				false
		 end
	end

	@doc """
	"""
	def normalize_command(%PlaceBid{} = command, bid_up) do
		normalized_max_value = command.max_value 
		|> normalize_value(bid_up)

		%PlaceBid{command | max_value: normalized_max_value, created_at: command.created_at || now()}
	end

	@doc """
	Aligns a bid mount to a bid_up boundary value
	
	Ex: Value=1.14 Bid_up=0.10 -> Value=1.10
	Ex: Value=1.19 Bid_up=0.10 -> Value=1.10
	Ex: Value=1.00 Bid_up=0.10 -> Value=1.00
	"""
	def normalize_value_not_used(value, bid_up) do
		# Float.round(Float.floor(value/bid_up)*bid_up,2)
	end

	def normalize_value(value, bid_up) do
		# {f, _} = D.with_context(%D.Context{precision: 9, rounding: :half_up}, fn -> D.mult(D.div_int(D.new(value), D.new(bid_up)), D.new(bid_up)) end)
		{integer_part, _} = D.div(D.new(value), D.new(bid_up)) |> D.to_string(:normal) |> Integer.parse

		{f, _} = D.with_context(%D.Context{precision: 9, rounding: :half_up}, fn -> D.mult(D.new(integer_part), D.new(bid_up)) end)
		|> D.to_string(:normal)
		|> Float.parse

		f
	end

	@doc """
	Generates a unique worker id
	"""
	def make_worker_id(auction_id) do
		{:auction, auction_id}
	end

	@doc """
	Schedules a timer that will be fired at the auctions's end time

	Returns the given fsm auction updated with the timer ref or the unchanged
	fsm auction if the time could not be started
	"""
	#def start_ticker({:ok, %FsmAuction{} = fsm}) do
	#	{:ok, start_ticker(fsm, nil)}
	#end

	def start_ticker(%FsmAuction{} = fsm, pid \\ nil) do
		now = now()

		cond do

			fsm.state == :scheduled and fsm.data.start_date_time >= now ->
				delay = (fsm.data.start_date_time - now) * 1000
				Logger.info("Auction #{fsm.data.auction_id} scheduling_auction_ticker in #{delay} ms")
				{:ok, ticker_ref} = :timer.send_after(delay, pid || self(), :scheduling_auction_ticker)
				put_in(fsm.data.ticker_ref, ticker_ref)

			fsm.state == :started and fsm.data.end_date_time >= now ->
				delay = (fsm.data.end_date_time - now) * 1000
				Logger.info("Auction #{fsm.data.auction_id} closing_auction_ticker in #{delay} ms")
				{:ok, ticker_ref} = :timer.send_after(delay, pid || self(), :closing_auction_ticker)
				put_in(fsm.data.ticker_ref, ticker_ref)

			true ->
				fsm

		end
	end

	@doc """
	"""
	def maybe_restart_ticker(fsm, pid \\ nil)

	def maybe_restart_ticker(%FsmAuction{data: %FsmAuctionData{bids: [_h|_t]}} = fsm, pid) do
		if hd(fsm.data.bids).time_extended == true do
			fsm
			|> stop_ticker
			|> start_ticker
		else
			fsm
		end
	end

	def maybe_restart_ticker(%FsmAuction{} = fsm, pid) do
		fsm
	end

	@doc """
	"""
	def stop_ticker(%FsmAuction{} = fsm) do
		if fsm.data.ticker_ref != nil do
			:timer.cancel(fsm.data.ticker_ref)
		end

		put_in(fsm.data.ticker_ref, nil)
	end

	@doc """
	"""
	def clear_ticker(%FsmAuction{} = fsm) do
		put_in(fsm.data.ticker_ref, nil)
	end

	@doc """
	"""
	# TODO Read this from the database / ETS table
	def get_days_given_listed_time_id(listed_time_id) do
		case listed_time_id do
			1 -> 3
			2 -> 5
			3 -> 7
			4 -> 10
			5 -> 30
		end
	end

	@doc """
	"""
	def compute_end_date_time(start_date_time, listed_time_id) do
		start_date_time + get_days_given_listed_time_id(listed_time_id) * (60 * 60 * 24)
	end

	@doc """
	"""
	def whereis(auction_id) do
		worker_name(auction_id)
		|> :global.whereis_name
	end

	@doc """
	"""
	def via_tuple(auction_id) do
		{:global, worker_name(auction_id)}
	end

	@doc """
	Generates a unique worker name
	"""
	def worker_name(auction_id) do
		{:auction_worker, auction_id}
	end


end
