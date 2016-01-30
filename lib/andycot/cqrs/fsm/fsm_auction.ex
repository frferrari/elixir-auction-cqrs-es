defmodule Andycot.FsmAuction do 
	@moduledoc """
	"""
	use Fsm, initial_state: :idle, initial_data: %Andycot.FsmAuctionData{}
	alias Andycot.Repo
	alias Andycot.Event.Auction.{BidPlaced}
	alias Andycot.FsmAuctionData
	alias Andycot.Model.UserEvent
	import Andycot.Tools.Timestamp
	alias Decimal, as: D

	require Logger

	# TODO export to a configuration file
	@seconds_to_extend 5

	#
	# 	  ###   ######  #       #######
	# 	   #    #     # #       #
	# 	   #    #     # #       #
	# 	   #    #     # #       #####
	# 	   #    #     # #       #
	# 	   #    #     # #       #
	# 	  ###   ######  ####### #######
	# 	
	defstate idle do

		#
		defevent auction_started(event, mode), data: fsm_data do

			new_fsm_data = struct(FsmAuctionData, Map.from_struct(event))

			event
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(:started, new_fsm_data)

		end

		#
		defevent auction_scheduled(event, mode), data: fsm_data do

			new_fsm_data = struct(FsmAuctionData, Map.from_struct(event)) 

			event
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(:scheduled, new_fsm_data)

		end

		#
		defevent _, state: state do
			next_state(state)
		end

	end

	#
	# 	 #####   #####  #     # ####### ######  #     # #       ####### ######
	# 	#     # #     # #     # #       #     # #     # #       #       #     #
	# 	#       #       #     # #       #     # #     # #       #       #     #
	# 	 #####  #       ####### #####   #     # #     # #       #####   #     #
	# 	      # #       #     # #       #     # #     # #       #       #     #
	# 	#     # #     # #     # #       #     # #     # #       #       #     #
	# 	 #####   #####  #     # ####### ######   #####  ####### ####### ######
	# 	
	defstate scheduled do

		#
		defevent auction_started(event, mode), data: fsm_data do
			event
			|> Repo.persist_event(mode, fsm_data)

			next_state(:started)
		end

		# An auction was closed
		defevent auction_closed(event, mode), state: state, data: fsm_data do

			new_fsm_data = %FsmAuctionData{fsm_data | closed_by: event.closed_by, end_date_time: event.created_at || now()}

			event 
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(:closed, new_fsm_data)

		end

		# An auction was suspended
		defevent auction_suspended(event, mode), state: state, data: fsm_data do

			new_fsm_data = %FsmAuctionData{fsm_data | suspended_at: event.created_at || now()}

			event 
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(:suspended, new_fsm_data)

		end

		# A renew event was rejected
		defevent resume_rejected(event, mode), state: state, data: fsm_data do

			event 
			|> Repo.persist_event(mode, fsm_data)

			next_state(state, fsm_data)
			
		end

		#
		defevent _, state: state do
			next_state(state)
		end

	end

	#
	# 	 #####  #######    #    ######  ####### ####### ######
	# 	#     #    #      # #   #     #    #    #       #     #
	# 	#          #     #   #  #     #    #    #       #     #
	# 	 #####     #    #     # ######     #    #####   #     #
	# 	      #    #    ####### #   #      #    #       #     #
	# 	#     #    #    #     # #    #     #    #       #     #
	# 	 #####     #    #     # #     #    #    ####### ######
	# 	
	defstate started do

		# A bid was placed on an auction and it is the first bid
		defevent bid_placed(event, mode), state: state, data: fsm_data = %FsmAuctionData{sale_type_id: 1, bids: []} do

			{new_end_date_time, is_time_extended} = if fsm_data.time_extension == true do
				{fsm_data.end_date_time+@seconds_to_extend, true}
			else
				{fsm_data.end_date_time, false}
			end

			# If the auction has a reserve price and the bid max value is >= reserve_price then the current_price is raised
			# to reach the value of the reserve_price. This allows a bidder who would be the sole bidder to win the auction.
			new_current_price = if fsm_data.reserve_price != nil and event.max_value >= fsm_data.reserve_price do
				fsm_data.reserve_price
			else
				fsm_data.current_price
			end

			new_bid = make_bid_from_event(event, %{	is_visible: true, 
																							is_auto: false, 
																							time_extended: is_time_extended, 
																							value: new_current_price, 
																							created_at: now()})

			new_fsm_data = %FsmAuctionData{fsm_data | end_date_time: new_end_date_time,	
																								current_price: new_current_price,
																								bids: [Map.from_struct(new_bid)]}

			event 
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(state, new_fsm_data)
		end

		# A bid was placed on an auction that already has at least one bid
		defevent bid_placed(event, mode), state: state, data: fsm_data = %FsmAuctionData{sale_type_id: 1, bids: [_h|_t]} do

	 		highest_bid = hd(fsm_data.bids)
	 		{time_extended, time_extended_fsm_data} = maybe_extend_time(fsm_data)

	 		new_fsm_data = cond do

	 			event.bidder_id == highest_bid.bidder_id and time_extended_fsm_data.reserve_price == nil ->
		 			# The current highest bidder wants to raise its max bid price.
		 			# The auction's current price doesn't change, and the new bid isn't visible
					new_bid = make_bid_from_event(event, %{	is_visible: false, 
																									is_auto: false, 
																									time_extended: time_extended,
																									value: time_extended_fsm_data.current_price,
																									created_at: now()})

					time_extended_fsm_data
					|> update_current_price_and_bids(time_extended_fsm_data.current_price, [Map.from_struct(new_bid)])

	 			event.bidder_id == highest_bid.bidder_id and time_extended_fsm_data.reserve_price != nil ->
		 			# The current highest bidder wants to raise its max bid price.
		 			#
					# If the bid max value is >= reserve_price and its the first time we exceed the reserve price
					# then the current_price is raised to reach the value of the reserve_price and the bid is visible.
					{is_visible, new_current_price} = if event.max_value >= time_extended_fsm_data.reserve_price do
						if time_extended_fsm_data.current_price < time_extended_fsm_data.reserve_price do
							{true, time_extended_fsm_data.reserve_price}
						else
							{false, time_extended_fsm_data.current_price}
						end
					else
							{false, time_extended_fsm_data.current_price}
					end

					new_bid = make_bid_from_event(event, %{	is_visible: is_visible, 
																									is_auto: false, 
																									time_extended: time_extended,
																									value: new_current_price, 
																									created_at: now()})

					time_extended_fsm_data
					|> update_current_price_and_bids(new_current_price, [Map.from_struct(new_bid)])

				event.max_value <= highest_bid.max_value ->
					#
		 			# Case of a bid that is greater than the current price AND lower than the highest bidder max bid
		 			# The highest bidder keeps its position of highest bidder, and we raise the current price to the
		 			# bid max value
					#
					new_current_price = event.max_value

					new_bid = make_bid_from_event(event, %{	is_visible: true, 
																									is_auto: false, 
																									time_extended: time_extended,
																									value: new_current_price, 
																									created_at: now()})

					new_highest_bid = %{highest_bid | is_visible: true, is_auto: true, time_extended: time_extended, value: new_current_price}

					time_extended_fsm_data
					|> update_current_price_and_bids(new_current_price, [new_highest_bid, Map.from_struct(new_bid)])

				true ->
					#
					# Case when the bid max value is greater than the highest_bid max value
					# The current highest_bidder losts its status of highest bidder
					#
					# If the auction has a reserve price and the bid max value is >= reserve_price then the current_price is raised
					# to reach the value of the reserve_price.
					new_current_price = if time_extended_fsm_data.reserve_price != nil do
						if event.max_value >= time_extended_fsm_data.reserve_price do
							time_extended_fsm_data.reserve_price
						else
							add_amounts(highest_bid.max_value, time_extended_fsm_data.bid_up)
						end
					else
						add_amounts(highest_bid.max_value, time_extended_fsm_data.bid_up)
					end

					new_highest_bid = make_bid_from_event(event, %{	is_visible: true, 
																													is_auto: false, 
																													time_extended: time_extended,
																													value: new_current_price, 
																													created_at: now()})

					# We don't generate an automatic bid for the current highest bidder if the auction's price has already reached
					# the highest bidder max bid value
					if time_extended_fsm_data.current_price == highest_bid.max_value do
						time_extended_fsm_data
						|> update_current_price_and_bids(new_current_price, [Map.from_struct(new_highest_bid)])
					else
						new_bid = %{highest_bid | is_visible: true, is_auto: true, time_extended: time_extended, value: highest_bid.max_value}

						time_extended_fsm_data
						|> update_current_price_and_bids(new_current_price, [Map.from_struct(new_highest_bid), new_bid])
					end
	 		end

			event 
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(state, new_fsm_data)
		end

		# A bid was placed on a fixed price auction
		defevent bid_placed(event, mode), state: state, data: fsm_data = %FsmAuctionData{sale_type_id: 2} do

	 		new_stock = fsm_data.stock - event.requested_qty

	 		new_fsm_data = cond do

			 	new_stock == 0 ->
		 			Logger.info("Auction #{fsm_data.auction_id} sold for a qty of #{event.requested_qty}, no remaining stock")

					new_bid = make_bid_from_event(event, %{is_visible: true, is_auto: false, value: event.max_value, created_at: now()})
					
					%FsmAuctionData{fsm_data | 	closed_by: nil, 
																			original_stock: event.requested_qty, 
																			stock: 0, 
																			end_date_time: event.created_at, 
																			bids: [Map.from_struct(new_bid)]}

				true ->
		 			Logger.info("Auction #{fsm_data.auction_id} sold for a qty of #{event.requested_qty}, remaining stock is #{new_stock}, duplicate the auction")

					new_bid = make_bid_from_event(event, %{is_visible: true, is_auto: false, value: event.max_value, created_at: now()})

					%FsmAuctionData{fsm_data | 	closed_by: nil,
																			original_stock: event.requested_qty, 
																			stock: 0,
																			clone_parameters: %{stock: new_stock, 
																													start_date_time: fsm_data.start_date_time, 
																													end_date_time: fsm_data.end_date_time},
																			end_date_time: event.created_at, 
																			bids: [Map.from_struct(new_bid)]}

	 		end

			event 
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(state, new_fsm_data)
		end

		# A bid event was rejected
		defevent bid_rejected(event, mode), state: state, data: fsm_data do

			event 
			|> Repo.persist_event(mode, fsm_data)

			next_state(state, fsm_data)
		end

		# A close event was rejected
		defevent close_rejected(event, mode), state: state, data: fsm_data do

			event 
			|> Repo.persist_event(mode, fsm_data)

			next_state(state, fsm_data)
		end

		# An auction was closed
		defevent auction_closed(event, mode), state: state, data: fsm_data do

			new_fsm_data = %FsmAuctionData{fsm_data | closed_by: event.closed_by, 
																								end_date_time: event.created_at || now(),
																								ticker_ref: nil}

			event 
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(:closed, new_fsm_data)
		end

		# An auction was sold
		defevent auction_sold(event, mode), state: state, data: fsm_data do

			new_fsm_data = %FsmAuctionData{fsm_data | closed_by: UserEvent.get_closed_by_system,
																								is_sold: true, 
																								original_stock: event.sold_qty,
																								stock: 0,
																								end_date_time: event.created_at || now(),
																								ticker_ref: nil}

			event 
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(:sold, new_fsm_data)
		end

		# An auction was suspended
		defevent auction_suspended(event, mode), state: state, data: fsm_data do

			new_fsm_data = %FsmAuctionData{fsm_data | suspended_at: event.created_at || now()}

			event 
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(:suspended, new_fsm_data)
		end

		# A suspend event was rejected
		defevent suspend_rejected(event, mode), state: state, data: fsm_data do

			event 
			|> Repo.persist_event(mode, fsm_data)

			next_state(state, fsm_data)
		end

		# A renew event was rejected
		defevent renew_rejected(event, mode), state: state, data: fsm_data do

			event 
			|> Repo.persist_event(mode, fsm_data)

			next_state(state, fsm_data)
		end

		# Increment the auction's watch count
		defevent watch_count_incremented(event, mode), state: state, data: fsm_data do

			new_fsm_data = %FsmAuctionData{fsm_data | watch_count: fsm_data.watch_count+1}

			event 
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(state, new_fsm_data)
		end

		# Decrement the auction's watch count
		defevent watch_count_decremented(event, mode), state: state, data: fsm_data do

			new_fsm_data = if fsm_data.watch_count > 0 do
				%FsmAuctionData{fsm_data | watch_count: fsm_data.watch_count-1}
			else
				fsm_data
			end

			event 
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(state, new_fsm_data)
		end

		# Increment the auction's visit count
		defevent visit_count_incremented(event, mode), state: state, data: fsm_data do

			new_fsm_data = %FsmAuctionData{fsm_data | visit_count: fsm_data.visit_count+1}

			event 
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(state, new_fsm_data)
		end

		#
		defevent _, state: state do
			next_state(state)
		end

	end

	# 	
	# 	 #####  ####### #       ######
	# 	#     # #     # #       #     #
	# 	#       #     # #       #     #
	# 	 #####  #     # #       #     #
	# 	      # #     # #       #     #
	# 	#     # #     # #       #     #
	# 	 #####  ####### ####### ######
	# 	
	defstate sold do

		#
		defevent _, state: state do
			next_state(state)
		end

	end

	# 	
	# 	 #####  #       #######  #####  ####### ######
	# 	#     # #       #     # #     # #       #     #
	# 	#       #       #     # #       #       #     #
	# 	#       #       #     #  #####  #####   #     #
	# 	#       #       #     #       # #       #     #
	# 	#     # #       #     # #     # #       #     #
	# 	 #####  ####### #######  #####  ####### ######
	# 	
	defstate closed do

		# An auction was requested to be renewed
		defevent auction_renewed(event, mode), state: state, data: fsm_data do

			#
			# The process of renewing an auction depends whether the closed auction holds or doesn't hold bids.
			#
			# Holds bids : 
			# -----------------------------------------------------------------------------------------
			# When an auction with a reserve price has received bid(s) BUT the highest bid price was still
			# below the reserve price when the auction ended, then the auction is closed but not sold, and
			# if the automatic renewal mode is OFF the auction is NOT automatically renewed (it stays closed).
			# In this case when the auction is manually requested to be renewed, we don't want to lose the list
			# of bids that were initialy placed. 
			# That's why we clone the auction and leave the original one closed and with its list of bids.
			# Note that the original "closed auction" can no longer be renewed in that case.
			#
			# Doesn't hold bids :
			# -----------------------------------------------------------------------------------------
			# This is the case when an auction ended naturally without any bids. In this case we can 
			# simply restart the original auction without cloNing it.
			#

			{new_state, new_fsm_data} = if length(fsm_data.bids) == 0 do

				updated_fsm_data = %FsmAuctionData{fsm_data | closed_by: nil,
																											start_date_time: event.start_date_time,
																											end_date_time: event.end_date_time,
																											renewal_count: fsm_data.renewal_count+1}

				updated_state = if updated_fsm_data.start_date_time > now() do
					:scheduled
				else
					:started
				end

				{updated_state, updated_fsm_data}

			else

				updated_fsm_data = %FsmAuctionData{fsm_data |	original_stock: fsm_data.stock,
																											stock: 0,
																											clone_parameters: %{stock: fsm_data.stock, 
																																					start_date_time: event.start_date_time, 
																																					end_date_time: event.end_date_time},
																											renewal_count: fsm_data.renewal_count+1}

				updated_state = state

				{updated_state, updated_fsm_data}

			end

			event 
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(new_state, new_fsm_data)
		end

		#
		defevent _, state: state do
			next_state(state)
		end

	end

	# 	
	# 	 #####  #     #  #####  ######  ####### #     # ######  ####### ######
	# 	#     # #     # #     # #     # #       ##    # #     # #       #     #
	# 	#       #     # #       #     # #       # #   # #     # #       #     #
	# 	 #####  #     #  #####  ######  #####   #  #  # #     # #####   #     #
	# 	      # #     #       # #       #       #   # # #     # #       #     #
	# 	#     # #     # #     # #       #       #    ## #     # #       #     #
	# 	 #####   #####   #####  #       ####### #     # ######  ####### ######
	# 	
	defstate suspended do

		# An auction was resumed
		defevent auction_resumed(event, mode), state: state, data: fsm_data do

			{new_state, new_fsm_data} = if length(fsm_data.bids) == 0 do

				updated_fsm_data = %FsmAuctionData{fsm_data | suspended_at: nil,
																											start_date_time: event.start_date_time,
																											end_date_time: event.end_date_time,
																											renewal_count: fsm_data.renewal_count+1}

				updated_state = if updated_fsm_data.start_date_time > now() do
					:scheduled
				else
					:started
				end

				{updated_state, updated_fsm_data}

			else

				updated_fsm_data = %FsmAuctionData{fsm_data |	closed_by: UserEvent.get_closed_by_system,
																											original_stock: fsm_data.stock,
																											stock: 0,
																											clone_parameters: %{stock: fsm_data.stock, 
																																					start_date_time: event.start_date_time, 
																																					end_date_time: event.end_date_time},
																											renewal_count: fsm_data.renewal_count+1}

				# The current auction is CLOSED and a cloned auction will be created (clone_parameters)
				updated_state = :closed

				{updated_state, updated_fsm_data}

			end

			event 
			|> Repo.persist_event(mode, new_fsm_data)

			next_state(new_state, new_fsm_data)
		end

		#
		defevent _, state: state do
			next_state(state)
		end

	end

	@doc """
	Helper function used when merging two maps where we want to keep the values of the map given as the right parameter
	"""
	def map_merge_keep_right(_k, vl, vr) do
		vr || vl
	end

	@doc """
	"""
	def make_bid_from_event(%BidPlaced{} = event, overwrite \\ %{}) do
		Map.merge(event, struct(State.Bid, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def maybe_extend_time(%FsmAuctionData{time_extension: true} = fsm_data) do
		{true, Map.put(fsm_data, :end_date_time, fsm_data.end_date_time+@seconds_to_extend)} #%FsmAuctionData{fsm_data | end_date_time: fsm_data.end_date_time+@seconds_to_extend}}
	end

	def maybe_extend_time(%FsmAuctionData{time_extension: false} = fsm_data) do
		{false, fsm_data}
	end

	@doc """
	"""
	def update_current_price_and_bids(%FsmAuctionData{} = fsm_data, new_current_price, new_bids) do
		%FsmAuctionData{fsm_data | 	current_price: new_current_price,
																	bids: List.flatten([new_bids | fsm_data.bids])}
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
