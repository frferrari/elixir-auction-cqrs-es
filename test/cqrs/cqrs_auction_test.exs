defmodule Cqrs.Auction.Test do
	use ExUnit.Case, async: false
	import Andycot.EventProcessor.Auction

	alias Andycot.Command.User.{RegisterUser, ActivateAccount, WatchAuction, UnwatchAuction}
	alias Andycot.Command.Auction.{CreateAuction, PlaceBid, CloseAuction, SuspendAuction, RenewAuction, ResumeAuction}

	alias Andycot.Event.Auction.{AuctionStarted, AuctionScheduled}
	alias Andycot.Event.Auction.{BidPlaced, BidRejected}
	alias Andycot.Event.Auction.{AuctionSuspended, SuspendRejected, RenewRejected, AuctionResumed, ResumeRejected}

	alias Andycot.AuctionSupervisor
	alias Andycot.UserSupervisor
	alias Andycot.Model.UserEvent
	alias Andycot.FsmAuction
	import Andycot.Tools.Timestamp

	#
	# Some info regarding the terminology used in the test titles
	#
	# VP 		= Variable Price auction
	# FP 		= Fixed Price auction
	# RP 		= Reserve Price
	# AR 		= Automatic Renewal
	#
	# w/RP 	= with Reserve Price
	# wo/RP = without Reserve Price
	#
	# w/AR 	= with Automatic Renewal
	# wo/AR = without Automatic Renewal
	#
	# w/TE 	= with Time Extension
	# wo/TE = without Time Extension
	#

	setup_all do
		{seller_id, buyer_id_a, buyer_id_b, buyer_id_c} = register_and_activate_user(:standard)

		{:ok, [	mode: :standard, 
						seller_id: seller_id,
						buyer_id_a: buyer_id_a,
						buyer_id_b: buyer_id_b,
						buyer_id_c: buyer_id_c
					]
		}
	end

	def wait_for_the_end(end_date_time) do
		delay = (end_date_time-now()+1)*1000
		:timer.sleep(delay)
	end

	def random_string(length \\ 16) do
	  :crypto.strong_rand_bytes(length) |> Base.url_encode64 |> binary_part(0, length)
	end

	def register_and_activate_user(mode) do
		now = now()

		register_seller_command = %{	user_id: nil,
																	email: random_string,
																	password: "mypassword",
																	algorithm: "sha128",
																	salt: "mysalt",
																	nickname: "seller",
																	is_super_admin: false,
																	is_newsletter: false,
																	is_receive_renewals: false,
																	last_login_at: now,
																	token: "mytoken",
																	currency_id: 7,
																	last_name: "Jobs",
																	first_name: "Steve",
																	lang: "fr",
																	avatar: "myavatar",
																	date_of_birth: "24/02/1955",
																	phone: "myphone",
																	mobile: "mymobile",
																	fax: "myfax",
																	description: "mydescription",
																	sending_country: "mysendingcountry",
																	invoice_name: "myinvoicename",
																	invoice_address1: "myinvoiceaddress1",
																	invoice_address2: "myinvoiceaddress2",
																	invoice_zip_code: "myinvoicezipcode",
																	invoice_city: "myinvoicecity",
																	invoice_country: "myinvoicecountry",
																	vat_intra: "myvatintra",
																	holiday_start_at: now,
																	holiday_end_at: now+3600,
																	holiday_hide_id: 1,
																	bid_up: 0.10,
																	autotitle_id: 2,
																	listed_time_id: 3,
																	slug: "myslug",
																	created_at: now()
																}

		{:ok, seller_fsm} = UserSupervisor.register_user(struct(RegisterUser, register_seller_command), mode)

		UserSupervisor.activate_account(%ActivateAccount{user_id: seller_fsm.data.user_id})

		register_buyer_a_command = %{	user_id: nil,
																	email: random_string,
																	password: "mypassword",
																	algorithm: "sha128",
																	salt: "mysalt",
																	nickname: random_string,
																	is_super_admin: false,
																	is_newsletter: false,
																	is_receive_renewals: false,
																	last_login_at: now,
																	token: "mytoken",
																	currency_id: 7,
																	last_name: "Jobs",
																	first_name: "Steve",
																	lang: "fr",
																	avatar: "myavatar",
																	date_of_birth: "24/02/1955",
																	phone: "myphone",
																	mobile: "mymobile",
																	fax: "myfax",
																	description: "mydescription",
																	sending_country: "mysendingcountry",
																	invoice_name: "myinvoicename",
																	invoice_address1: "myinvoiceaddress1",
																	invoice_address2: "myinvoiceaddress2",
																	invoice_zip_code: "myinvoicezipcode",
																	invoice_city: "myinvoicecity",
																	invoice_country: "myinvoicecountry",
																	vat_intra: "myvatintra",
																	holiday_start_at: now,
																	holiday_end_at: now+3600,
																	holiday_hide_id: 1,
																	bid_up: 0.10,
																	autotitle_id: 2,
																	listed_time_id: 3,
																	slug: "myslug",
																	created_at: now()
																}
		{:ok, buyer_fsm_a} = UserSupervisor.register_user(struct(RegisterUser, register_buyer_a_command), mode)
		UserSupervisor.activate_account(%ActivateAccount{user_id: buyer_fsm_a.data.user_id})

		register_buyer_b_command = %{register_buyer_a_command | email: random_string, nickname: random_string}
		{:ok, buyer_fsm_b} = UserSupervisor.register_user(struct(RegisterUser, register_buyer_b_command), mode)
		UserSupervisor.activate_account(%ActivateAccount{user_id: buyer_fsm_b.data.user_id})

		register_buyer_c_command = %{register_buyer_a_command | email: random_string, nickname: random_string}
		{:ok, buyer_fsm_c} = UserSupervisor.register_user(struct(RegisterUser, register_buyer_c_command), mode)
		UserSupervisor.activate_account(%ActivateAccount{user_id: buyer_fsm_c.data.user_id})

		{seller_fsm.data.user_id, buyer_fsm_a.data.user_id, buyer_fsm_b.data.user_id, buyer_fsm_c.data.user_id}
	end

	#setup context do
	#	:ok
	#end

	#
	# 		#######    #      ###   #
	# 		#         # #      #    #
	#			#        #   #     #    #
	#			#####   #     #    #    #
	#			#       #######    #    #
	#			#       #     #    #    #
	#			#       #     #   ###   #######
	#

	test "It should fail when placing ONE bid on your own auction", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+3600, 
																		start_price: 1.00,
																		stock: 6}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		place_bid = %PlaceBid{auction_id: started_fsm.data.auction_id,
													bidder_id: context[:seller_id], 
													bidder_name: "rapanui", 
													requested_qty: 2,
													max_value: 1.10}

		{:error, %BidRejected{reason: :self_bidding} = _event, _bid_placed_fsm} = AuctionSupervisor.place_bid(place_bid)
	end

	test "It should fail when placing ONE bid on a FP auction with a wrong price", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+3600, 
																		start_price: 1.00,
																		stock: 6}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		place_bid = %PlaceBid{auction_id: started_fsm.data.auction_id,
													bidder_id: context[:buyer_id_a], 
													bidder_name: "rapanui", 
													requested_qty: 2,
													max_value: 1.10}

		{:error, %BidRejected{reason: :wrong_bid_price} = _event, _bid_placed_fsm} = AuctionSupervisor.place_bid(place_bid)
	end

	test "It should fail when placing ONE bid on a closed auction", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+3600, 
																		start_price: 1.00,
																		stock: 6}
		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		# Closing the auction
		close_auction = %CloseAuction{auction_id: started_fsm.data.auction_id, closed_by: context[:seller_id]}
		{:ok, _closed_event, _closed_fsm} = AuctionSupervisor.close_auction(close_auction, context[:mode])

		# Bidding on a closed auction
		place_bid = %PlaceBid{auction_id: started_fsm.data.auction_id,
													bidder_id: context[:seller_id], 
													bidder_name: "rapanui", 
													requested_qty: 2,
													max_value: 1.10}
		{:error, %BidRejected{reason: :auction_state_mismatch} = _event, _bid_placed_fsm} = AuctionSupervisor.place_bid(place_bid)
	end

	test "It should fail when placing ONE bid on a suspended auction", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+3600, 
																		start_price: 1.00,
																		stock: 6}
		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		# Suspend the auction
		suspend_auction = %SuspendAuction{auction_id: started_fsm.data.auction_id, suspended_by: UserEvent.get_suspended_by_system}
		{:ok, _suspended_event, _suspended_fsm} = AuctionSupervisor.suspend_auction(suspend_auction, context[:mode])

		# Bidding on a suspended auction
		place_bid = %PlaceBid{auction_id: started_fsm.data.auction_id,
													bidder_id: context[:seller_id], 
													bidder_name: "rapanui", 
													requested_qty: 2,
													max_value: 1.10}
		{:error, %BidRejected{reason: :auction_is_suspended} = _event, _bid_placed_fsm} = AuctionSupervisor.place_bid(place_bid)
	end

	test "It should fail when placing ONE bid on an auction that hasn't yet started", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now+1800, 
																		end_date_time: now+3600, 
																		start_price: 1.00,
																		stock: 6}
		{:ok, scheduled_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert scheduled_fsm.state == :scheduled
		assert scheduled_fsm.data.ticker_ref != nil

		# Bidding on a pending auction
		place_bid = %PlaceBid{auction_id: scheduled_fsm.data.auction_id,
													bidder_id: context[:buyer_id_a], 
													bidder_name: "rapanui", 
													requested_qty: 2,
													max_value: 1.00}
		{:error, %BidRejected{reason: :auction_not_yet_started} = _event, bid_rejected_fsm} = AuctionSupervisor.place_bid(place_bid)
		assert bid_rejected_fsm.state == :scheduled
	end

	test "It should fail when placing ONE bid with a qty greater than the available stock", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+3600, 
																		start_price: 1.00,
																		stock: 6}
		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		# Bidding on a pending auction
		place_bid = %PlaceBid{auction_id: started_fsm.data.auction_id,
													bidder_id: context[:buyer_id_a], 
													bidder_name: "rapanui", 
													requested_qty: 7,
													max_value: 1.00}
		{:error, %BidRejected{reason: :not_enough_stock} = _event, bid_rejected_fsm} = AuctionSupervisor.place_bid(place_bid)
		assert bid_rejected_fsm.state == :started
	end

	test "It should fail when renewing a started auction", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+3600, 
																		start_price: 1.00,
																		stock: 6}
		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		# Renewing a started auction
		renew_auction = %RenewAuction{auction_id: started_fsm.data.auction_id, renewed_by: context[:seller_id]}
		{:error, %RenewRejected{reason: :not_closed} = _event, renewed_fsm} = AuctionSupervisor.renew_auction(renew_auction, context[:mode])
		assert renewed_fsm.state == :started
	end

	test "It should fail when renewing a scheduled auction", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now+1800, 
																		end_date_time: now+3600, 
																		start_price: 1.00,
																		stock: 6}
		{:ok, scheduled_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert scheduled_fsm.data.ticker_ref != nil

		# Renewing a scheduled auction
		renew_auction = %RenewAuction{auction_id: scheduled_fsm.data.auction_id, renewed_by: context[:seller_id]}
		{:error, %RenewRejected{reason: :not_closed} = _event, renewed_fsm} = AuctionSupervisor.renew_auction(renew_auction, context[:mode])
		assert renewed_fsm.state == :scheduled
	end

	test "It should fail when resuming a started auction", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+3600, 
																		start_price: 1.00,
																		stock: 6}
		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		# Renewing a started auction
		resume_auction = %ResumeAuction{auction_id: started_fsm.data.auction_id, resumed_by: context[:seller_id]}
		{:error, %ResumeRejected{reason: :not_suspended} = _event, resumed_fsm} = AuctionSupervisor.resume_auction(resume_auction, context[:mode])
		assert resumed_fsm.state == :started
	end

	test "It should fail when resuming a scheduled auction", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now+1800, 
																		end_date_time: now+3600, 
																		start_price: 1.00,
																		stock: 6}
		{:ok, scheduled_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert scheduled_fsm.data.ticker_ref != nil

		# Renewing a scheduled auction
		resume_auction = %ResumeAuction{auction_id: scheduled_fsm.data.auction_id, resumed_by: context[:seller_id]}
		{:error, %ResumeRejected{reason: :not_suspended} = _event, resumed_fsm} = AuctionSupervisor.resume_auction(resume_auction, context[:mode])
		assert resumed_fsm.state == :scheduled
	end

	test "It should fail when suspending an auction with a user that is not the 'system'", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+3600, 
																		start_price: 1.00,
																		stock: 6}
		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		# Suspend the auction
		suspend_auction = %SuspendAuction{auction_id: started_fsm.data.auction_id, suspended_by: context[:seller_id]}
		{:error, %SuspendRejected{reason: :not_allowed} = _event, suspended_fsm} = AuctionSupervisor.suspend_auction(suspend_auction, context[:mode])
		assert suspended_fsm.state == :started
	end

	test "It should fail when watching an auction with an unknown user", context do
		:unknown_user = UserSupervisor.watch_auction(%WatchAuction{user_id: 1_000_000, auction_id: 1})
	end

	test "It should fail when unwatching an auction with an unknown user", context do
		:unknown_user = UserSupervisor.unwatch_auction(%UnwatchAuction{user_id: 1_000_000, auction_id: 1})
	end

	#
	#			 #####  #     #  #####   #####  ####### ####### ######
	#			#     # #     # #     # #     # #       #       #     #
	#			#       #     # #       #       #       #       #     #
	#			 #####  #     # #       #       #####   #####   #     #
	#			      # #     # #       #       #       #       #     #
	#			#     # #     # #     # #     # #       #       #     #
	#			 #####   #####   #####   #####  ####### ####### ######
	#
	test "It should succeed when starting an auction" do
		fsm = apply_event(%AuctionStarted{}, FsmAuction.new, :replay)

		assert fsm.state == :started
	end

	test "It should succeed when scheduling an auction" do
		scheduled_fsm 	= apply_event(%AuctionScheduled{}, FsmAuction.new, :replay)

		assert scheduled_fsm.state == :scheduled
	end

	test "It should succeed when starting a scheduled an auction" do
		scheduled_fsm 	= apply_event(%AuctionScheduled{}, FsmAuction.new, :replay)
		started_fsm 		= apply_event(%AuctionStarted{}, scheduled_fsm, :replay)

		assert started_fsm.state == :started		
	end

	test "It should succeed when suspending an auction that hasn't yet started", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now+1800, 
																		end_date_time: now+3600, 
																		start_price: 1.00,
																		stock: 6}
		{:ok, scheduled_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert scheduled_fsm.state == :scheduled
		assert scheduled_fsm.data.ticker_ref != nil

		# Suspend the auction
		suspend_auction = %SuspendAuction{auction_id: scheduled_fsm.data.auction_id, suspended_by: UserEvent.get_suspended_by_system}
		{:ok, %AuctionSuspended{} = _event, suspended_fsm} = AuctionSupervisor.suspend_auction(suspend_auction, context[:mode])
		assert suspended_fsm.state == :suspended
	end

	test "It should succeed when closing an auction that hasn't yet started", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now+1000, 
																		end_date_time: now+3600, 
																		start_price: 1.00,
																		stock: 6}
		{:ok, scheduled_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert scheduled_fsm.state == :scheduled
		assert scheduled_fsm.data.ticker_ref != nil

		# Closing the auction
		close_auction = %CloseAuction{auction_id: scheduled_fsm.data.auction_id, closed_by: context[:seller_id]}
		{:ok, _closed_event, closed_fsm} = AuctionSupervisor.close_auction(close_auction, context[:mode])
		assert closed_fsm.state == :closed
	end

	test "It should succeed when resuming a suspended auction", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+3600, 
																		start_price: 1.00,
																		stock: 6}
		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.state == :started
		assert started_fsm.data.ticker_ref != nil

		# Suspend the auction
		suspend_auction = %SuspendAuction{auction_id: started_fsm.data.auction_id, suspended_by: UserEvent.get_suspended_by_system}
		{:ok, %AuctionSuspended{} = _event, suspended_fsm} = AuctionSupervisor.suspend_auction(suspend_auction, context[:mode])
		assert suspended_fsm.state == :suspended

		# Resume the auction
		resume_auction = %ResumeAuction{auction_id: started_fsm.data.auction_id, resumed_by: UserEvent.get_resumed_by_system}
		{:ok, %AuctionResumed{} = _event, resumed_fsm} = AuctionSupervisor.resume_auction(resume_auction, context[:mode])
		assert resumed_fsm.state == :started
	end

	test "It should succeed when scheduling an auction THEN it should start it", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now+5, 
																		end_date_time: now+3600, 
																		start_price: 1.00,
																		stock: 6}
		{:ok, scheduled_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert scheduled_fsm.state == :scheduled
		assert scheduled_fsm.data.ticker_ref != nil

		# Wait for the scheduling_auction_ticker to be handled
		wait_for_the_end(create_auction.start_date_time)

		# Started auction
		{:ok, started_fsm} = AuctionSupervisor.get_auction(scheduled_fsm.data.auction_id, true)
		assert started_fsm.state == :started
		assert started_fsm.data.start_date_time == create_auction.start_date_time
		assert started_fsm.data.end_date_time == create_auction.end_date_time
		assert started_fsm.data.is_sold == false
		assert started_fsm.data.suspended_at == nil
		assert started_fsm.data.closed_by == nil
		assert started_fsm.data.ticker_ref != nil
		assert started_fsm.data.ticker_ref != scheduled_fsm.data.ticker_ref
	end

	test "It should succeed when watching and unwatching auctions", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+3600,
																		start_price: 1.00,
																		stock: 6}
		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.state == :started
		assert started_fsm.data.ticker_ref != nil
		assert started_fsm.data.watch_count == 0

		watched_auction_a = 5
		watched_auction_b = started_fsm.data.auction_id

		# User "a" will watch auction "a" and "b" (watching the same auction multiple times increments
		# the watch_count only once per each auction watch)
		UserSupervisor.watch_auction(%WatchAuction{user_id: context[:buyer_id_a], auction_id: watched_auction_a})
		UserSupervisor.watch_auction(%WatchAuction{user_id: context[:buyer_id_a], auction_id: watched_auction_a})
		UserSupervisor.watch_auction(%WatchAuction{user_id: context[:buyer_id_a], auction_id: watched_auction_b})
		UserSupervisor.watch_auction(%WatchAuction{user_id: context[:buyer_id_a], auction_id: watched_auction_b})
		UserSupervisor.watch_auction(%WatchAuction{user_id: context[:buyer_id_a], auction_id: watched_auction_b})
		UserSupervisor.watch_auction(%WatchAuction{user_id: context[:buyer_id_a], auction_id: watched_auction_b})
		# Auction "b" will be watched by user "a", "b", "c"
		UserSupervisor.watch_auction(%WatchAuction{user_id: context[:buyer_id_b], auction_id: watched_auction_b})
		UserSupervisor.watch_auction(%WatchAuction{user_id: context[:buyer_id_c], auction_id: watched_auction_b})
		{:ok, user_fsm} = UserSupervisor.get_user(context[:buyer_id_a])
		assert user_fsm.data.watched_auctions == MapSet.new([watched_auction_a, watched_auction_b])

		# Check that the watch_count has been incremented
		{:ok, watched_fsm} = AuctionSupervisor.get_auction(watched_auction_b, true)
		assert watched_fsm.data.watch_count == 3

		# Unwatch auctions
		:ok = UserSupervisor.unwatch_auction(%UnwatchAuction{user_id: context[:buyer_id_a], auction_id: watched_auction_b})
		{:ok, user_fsm} = UserSupervisor.get_user(context[:buyer_id_a])
		assert user_fsm.data.watched_auctions == MapSet.new([watched_auction_a])

		:ok = UserSupervisor.unwatch_auction(%UnwatchAuction{user_id: context[:buyer_id_a], auction_id: watched_auction_a})
		{:ok, user_fsm} = UserSupervisor.get_user(context[:buyer_id_a])
		assert MapSet.size(user_fsm.data.watched_auctions) == 0

		# Check that the watch_count has been decremented
		{:ok, watched_fsm} = AuctionSupervisor.get_auction(watched_auction_b, true)
		assert watched_fsm.data.watch_count == 2
	end

	test "It should succeed when incrementing the visit count", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+3600,
																		watch_count: 8,
																		visit_count: 210,
																		start_price: 1.00,
																		bid_up: 0.20,
																		stock: 6}
		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.state == :started
		assert started_fsm.data.bid_up == create_auction.bid_up
		assert started_fsm.data.watch_count == create_auction.watch_count
		assert started_fsm.data.visit_count == create_auction.visit_count

		# Increment the visit_count 
		AuctionSupervisor.increment_visit_count(started_fsm.data.auction_id)
		AuctionSupervisor.increment_visit_count(started_fsm.data.auction_id)
		{:ok, incremented_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)
		assert incremented_fsm.data.visit_count == started_fsm.data.visit_count+2
	end

	test "It should succeed when placing ONE bid on a VP/wo/RP/w/TE auction, EXTENDED, SOLD, NOT CLONED", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+1,
																		time_extension: true,
																		start_price: 1.00,
																		stock: 1}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		place_bid = %PlaceBid{auction_id: started_fsm.data.auction_id,
													bidder_id: context[:buyer_id_a], 
													bidder_name: "rapanui", 
													requested_qty: 1,
													max_value: 1.00}

		{:ok, _event, bid_placed_fsm} = AuctionSupervisor.place_bid(place_bid)
		assert length(bid_placed_fsm.data.bids) == 1
		assert bid_placed_fsm.data.current_price == 1.00
		assert hd(bid_placed_fsm.data.bids).bidder_id == place_bid.bidder_id
		assert hd(bid_placed_fsm.data.bids).time_extended == true
		assert bid_placed_fsm.data.end_date_time > create_auction.end_date_time

		wait_for_the_end(bid_placed_fsm.data.end_date_time)

		{:ok, closed_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)
		assert closed_fsm.state == :sold
		assert closed_fsm.data.is_sold == true
		assert closed_fsm.data.closed_by != nil
		assert closed_fsm.data.cloned_to_auction_id == nil
	end

	test "It should succeed when placing ONE bid on a VP/wo/RP/wo/TE auction, NOT EXTENDED, SOLD, NOT CLONED", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+1,
																		time_extension: false,
																		start_price: 1.00,
																		bid_up: 0.20,
																		stock: 1}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		place_bid = %PlaceBid{auction_id: started_fsm.data.auction_id,
													bidder_id: context[:buyer_id_a], 
													bidder_name: "rapanui", 
													requested_qty: 1,
													max_value: 1.00}

		{:ok, _event, bid_placed_fsm} = AuctionSupervisor.place_bid(place_bid)
		assert length(bid_placed_fsm.data.bids) == 1
		assert bid_placed_fsm.data.current_price == 1.00
		assert hd(bid_placed_fsm.data.bids).bidder_id == place_bid.bidder_id
		assert hd(bid_placed_fsm.data.bids).time_extended == false
		assert bid_placed_fsm.data.end_date_time == create_auction.end_date_time

		wait_for_the_end(bid_placed_fsm.data.end_date_time)

		{:ok, closed_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)
		assert closed_fsm.state == :sold
		assert closed_fsm.data.is_sold == true
		assert closed_fsm.data.closed_by != nil
		assert closed_fsm.data.cloned_to_auction_id == nil
	end

	test "It should succeed when placing ONE bid on a VP/wo/RP/w/TE/w/AR/STOCK > 1 auction, EXTENDED, SOLD, CLONED", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+1,
																		time_extension: true,
																		automatic_renewal: true,
																		start_price: 1.00,
																		stock: 6}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		place_bid = %PlaceBid{auction_id: started_fsm.data.auction_id,
													bidder_id: context[:buyer_id_a], 
													bidder_name: "rapanui", 
													requested_qty: 1,
													max_value: 1.00}

		{:ok, _event, bid_placed_fsm} = AuctionSupervisor.place_bid(place_bid)
		assert length(bid_placed_fsm.data.bids) == 1
		assert bid_placed_fsm.data.current_price == 1.00
		assert hd(bid_placed_fsm.data.bids).bidder_id == place_bid.bidder_id
		assert hd(bid_placed_fsm.data.bids).time_extended == true
		assert bid_placed_fsm.data.end_date_time > create_auction.end_date_time

		wait_for_the_end(bid_placed_fsm.data.end_date_time)

		{:ok, closed_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)
		assert closed_fsm.state == :sold
		assert closed_fsm.data.is_sold == true
		assert closed_fsm.data.closed_by != nil
		assert closed_fsm.data.cloned_to_auction_id != nil
		assert length(closed_fsm.data.bids) == 1

		{:ok, cloned_fsm} = AuctionSupervisor.get_auction(closed_fsm.data.cloned_to_auction_id, true)
		assert cloned_fsm.state == :started
		assert cloned_fsm.data.is_sold == false
		assert cloned_fsm.data.closed_by == nil
		assert cloned_fsm.data.cloned_from_auction_id != nil
		assert cloned_fsm.data.stock == create_auction.stock-1
		assert cloned_fsm.data.original_stock == create_auction.stock-1
		assert cloned_fsm.data.start_price == create_auction.start_price
		assert cloned_fsm.data.current_price == create_auction.start_price
		assert length(cloned_fsm.data.bids) == 0
		assert cloned_fsm.data.renewal_count == 0
	end

	test "It should succeed when placing ONE bid on a VP/wo/RP/w/TE/wo/AR/STOCK > 1 auction, EXTENDED, SOLD, CLONED", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+1,
																		time_extension: true,
																		automatic_renewal: true,
																		start_price: 1.00,
																		stock: 6}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		place_bid = %PlaceBid{auction_id: started_fsm.data.auction_id,
													bidder_id: context[:buyer_id_a], 
													bidder_name: "rapanui", 
													requested_qty: 1,
													max_value: 1.00}

		{:ok, _event, bid_placed_fsm} = AuctionSupervisor.place_bid(place_bid)
		assert length(bid_placed_fsm.data.bids) == 1
		assert bid_placed_fsm.data.current_price == 1.00
		assert hd(bid_placed_fsm.data.bids).bidder_id == place_bid.bidder_id
		assert hd(bid_placed_fsm.data.bids).time_extended == true
		assert bid_placed_fsm.data.end_date_time > create_auction.end_date_time

		wait_for_the_end(bid_placed_fsm.data.end_date_time)

		{:ok, closed_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)
		assert closed_fsm.state == :sold
		assert closed_fsm.data.is_sold == true
		assert closed_fsm.data.closed_by != nil
		assert closed_fsm.data.cloned_to_auction_id != nil
		assert length(closed_fsm.data.bids) == 1

		{:ok, cloned_fsm} = AuctionSupervisor.get_auction(closed_fsm.data.cloned_to_auction_id, true)
		assert cloned_fsm.state == :started
		assert cloned_fsm.data.is_sold == false
		assert cloned_fsm.data.closed_by == nil
		assert cloned_fsm.data.cloned_to_auction_id == nil
		assert cloned_fsm.data.cloned_from_auction_id != nil
		assert cloned_fsm.data.stock == create_auction.stock-1
		assert cloned_fsm.data.original_stock == create_auction.stock-1
		assert cloned_fsm.data.start_price == create_auction.start_price
		assert cloned_fsm.data.current_price == create_auction.start_price
		assert length(cloned_fsm.data.bids) == 0
		assert cloned_fsm.data.renewal_count == 0
	end

	test "It should succeed when placing ONE bid on a VP/w/RP/wo/AR auction, BP < RP, NOT SOLD, NOT CLONED", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+1,
																		time_extension: false,
																		start_price: 1.00,
																		reserve_price: 2.00,
																		automatic_renewal: false,
																		stock: 1}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		place_bid = %PlaceBid{auction_id: started_fsm.data.auction_id,
													bidder_id: context[:buyer_id_a], 
													bidder_name: "rapanui", 
													requested_qty: 1,
													max_value: 1.00}

		{:ok, _event, bid_placed_fsm} = AuctionSupervisor.place_bid(place_bid)
		assert length(bid_placed_fsm.data.bids) == 1
		assert bid_placed_fsm.data.current_price == 1.00
		assert hd(bid_placed_fsm.data.bids).bidder_id == place_bid.bidder_id
		assert hd(bid_placed_fsm.data.bids).time_extended == false
		assert bid_placed_fsm.data.end_date_time == create_auction.end_date_time

		wait_for_the_end(bid_placed_fsm.data.end_date_time)

		{:ok, closed_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)
		assert closed_fsm.state == :closed
		assert closed_fsm.data.cloned_to_auction_id == nil
		assert closed_fsm.data.is_sold == false
		assert closed_fsm.data.closed_by != nil
	end

	test "It should succeed when RESUMING a SUSPENDED auction (case VP/w/RP/wo/AR auction with bid, BP < RP, NOT SOLD, NOT CLONED), CLONED, STARTED without bids", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+60,
																		time_extension: false,
																		start_price: 1.00,
																		reserve_price: 2.00,
																		automatic_renewal: false,
																		stock: 1}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		place_bid = %PlaceBid{auction_id: started_fsm.data.auction_id,
													bidder_id: context[:buyer_id_a], 
													bidder_name: "rapanui", 
													requested_qty: 1,
													max_value: 1.00}

		{:ok, _event, bid_placed_fsm} = AuctionSupervisor.place_bid(place_bid)
		assert length(bid_placed_fsm.data.bids) == 1
		assert bid_placed_fsm.data.current_price == 1.00
		assert hd(bid_placed_fsm.data.bids).bidder_id == place_bid.bidder_id
		assert hd(bid_placed_fsm.data.bids).time_extended == false
		assert bid_placed_fsm.data.end_date_time == create_auction.end_date_time

		# Suspend the auction
		suspend_auction = %SuspendAuction{auction_id: started_fsm.data.auction_id,
																			suspended_by: UserEvent.get_suspended_by_system}

		{:ok, _event, suspended_fsm} = AuctionSupervisor.suspend_auction(suspend_auction)
		assert suspended_fsm.state == :suspended
		assert suspended_fsm.data.ticker_ref == nil
		assert suspended_fsm.data.is_sold == false
		assert suspended_fsm.data.closed_by == nil
		assert suspended_fsm.data.cloned_to_auction_id == nil
		assert suspended_fsm.data.cloned_from_auction_id == nil
		assert suspended_fsm.data.current_price == create_auction.start_price
		assert suspended_fsm.data.stock == create_auction.stock
		assert suspended_fsm.data.original_stock == create_auction.stock
		assert length(suspended_fsm.data.bids) == 1

		# Resume the auction
		resume_auction = %ResumeAuction{auction_id: started_fsm.data.auction_id,
																		resumed_by: UserEvent.get_resumed_by_system,
																		start_date_time: now(),
																		end_date_time: now()+2,
																		created_at: now()}

		# Resumes an auction and checks that it is CLOSED and CLONED
		{:ok, _event, resumed_closed_fsm} = AuctionSupervisor.resume_auction(resume_auction)
		assert resumed_closed_fsm.state == :closed
		assert resumed_closed_fsm.data.ticker_ref == nil
		assert resumed_closed_fsm.data.is_sold == false
		assert resumed_closed_fsm.data.closed_by == UserEvent.get_closed_by_system
		assert resumed_closed_fsm.data.cloned_to_auction_id != nil
		assert resumed_closed_fsm.data.cloned_from_auction_id == nil
		assert resumed_closed_fsm.data.current_price == create_auction.start_price
		assert resumed_closed_fsm.data.stock == 0
		assert resumed_closed_fsm.data.original_stock == create_auction.stock
		assert length(resumed_closed_fsm.data.bids) == 1

		# Checks that the CLONED auction is now started
		{:ok, cloned_fsm} = AuctionSupervisor.get_auction(resumed_closed_fsm.data.cloned_to_auction_id, true)
		assert cloned_fsm.state == :started
		assert cloned_fsm.data.ticker_ref != nil
		assert cloned_fsm.data.is_sold == false
		assert cloned_fsm.data.closed_by == nil
		assert cloned_fsm.data.cloned_to_auction_id == nil
		assert cloned_fsm.data.cloned_from_auction_id == resumed_closed_fsm.data.auction_id
		assert cloned_fsm.data.current_price == create_auction.start_price
		assert cloned_fsm.data.stock == create_auction.stock
		assert cloned_fsm.data.original_stock == create_auction.stock
		assert length(cloned_fsm.data.bids) == 0
	end

	test "It should succeed when RENEWING an auction (case of VP/w/RP/wo/AR auction, BP < RP, NOT SOLD, NOT CLONED) closed with bids, CLONED, STARTED", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+1,
																		time_extension: false,
																		start_price: 1.00,
																		reserve_price: 2.00,
																		automatic_renewal: false,
																		stock: 1}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		place_bid = %PlaceBid{auction_id: started_fsm.data.auction_id,
													bidder_id: context[:buyer_id_a], 
													bidder_name: "rapanui", 
													requested_qty: 1,
													max_value: 1.00}

		{:ok, _event, bid_placed_fsm} = AuctionSupervisor.place_bid(place_bid)
		assert length(bid_placed_fsm.data.bids) == 1
		assert bid_placed_fsm.data.current_price == 1.00
		assert hd(bid_placed_fsm.data.bids).bidder_id == place_bid.bidder_id
		assert hd(bid_placed_fsm.data.bids).time_extended == false
		assert bid_placed_fsm.data.end_date_time == create_auction.end_date_time

		wait_for_the_end(bid_placed_fsm.data.end_date_time)

		{:ok, closed_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)
		assert closed_fsm.state == :closed
		assert closed_fsm.data.cloned_to_auction_id == nil
		assert closed_fsm.data.is_sold == false
		assert closed_fsm.data.closed_by != nil
		assert closed_fsm.data.stock == create_auction.stock
		assert closed_fsm.data.original_stock == create_auction.stock

		renew_auction = %RenewAuction{auction_id: closed_fsm.data.auction_id,
																	renewed_by: UserEvent.get_renewed_by_system,
																	start_date_time: now(),
																	end_date_time: now()+4,
																	created_at: now()}
		{:ok, _event, still_closed_fsm} = AuctionSupervisor.renew_auction(renew_auction)
		assert still_closed_fsm.state == :closed
		assert still_closed_fsm.data.cloned_to_auction_id != nil
		assert still_closed_fsm.data.is_sold == false
		assert still_closed_fsm.data.closed_by != nil
		assert still_closed_fsm.data.stock == 0
		assert still_closed_fsm.data.original_stock == create_auction.stock

		# Checks that a RENEW can be asked only ONCE on a closed auction holding bids
		renew_twice_auction = %RenewAuction{auction_id: closed_fsm.data.auction_id,
																				renewed_by: UserEvent.get_renewed_by_system,
																				start_date_time: now(),
																				end_date_time: now()+4,
																				created_at: now()}
		{:error, event, not_renewed_twice_fsm} = AuctionSupervisor.renew_auction(renew_twice_auction)
		# assert event == %RenewRejected{auction_id: closed_fsm.data.auction_id, reason: :already_renewed}
		assert event.reason == :already_renewed

		# Checks that the CLONED auction is STARTED
		{:ok, cloned_fsm} = AuctionSupervisor.get_auction(still_closed_fsm.data.cloned_to_auction_id, true)
		assert cloned_fsm.state == :started
		assert cloned_fsm.data.ticker_ref != nil
		assert cloned_fsm.data.cloned_to_auction_id == nil
		assert cloned_fsm.data.cloned_from_auction_id == still_closed_fsm.data.auction_id
		assert cloned_fsm.data.is_sold == false
		assert cloned_fsm.data.closed_by == nil
		assert cloned_fsm.data.stock == create_auction.stock
		assert cloned_fsm.data.original_stock == create_auction.stock
		assert cloned_fsm.data.renewal_count == closed_fsm.data.renewal_count+1
		assert length(cloned_fsm.data.bids) == 0

		# Waits for the CLONED auction to end
		wait_for_the_end(cloned_fsm.data.end_date_time)

		# Checks AGAIN that a RENEW can be asked only ONCE on a closed auction holding bids
		renew_thrice_auction = %RenewAuction{auction_id: closed_fsm.data.auction_id,
																				renewed_by: UserEvent.get_renewed_by_system,
																				start_date_time: now(),
																				end_date_time: now()+4,
																				created_at: now()}
		{:error, event_thrice, not_renewed_thrice_fsm} = AuctionSupervisor.renew_auction(renew_thrice_auction)
		assert event_thrice.reason == :already_renewed

		# Checks that the CLONED auction is now closed
		{:ok, closed_cloned_fsm} = AuctionSupervisor.get_auction(cloned_fsm.data.auction_id, true)
		assert closed_cloned_fsm.state == :closed
		assert closed_cloned_fsm.data.cloned_to_auction_id == nil
		assert closed_cloned_fsm.data.cloned_from_auction_id != nil
		assert closed_cloned_fsm.data.is_sold == false
		assert closed_cloned_fsm.data.closed_by != nil
		assert closed_cloned_fsm.data.stock == create_auction.stock
		assert closed_cloned_fsm.data.original_stock == create_auction.stock

		# Renew the CLOSED CLONED auction
		renew_cloned_auction = %RenewAuction{	auction_id: closed_cloned_fsm.data.auction_id,
																					renewed_by: UserEvent.get_renewed_by_system,
																					start_date_time: now(),
																					created_at: now()}
		{:ok, _event, renewed_cloned_fsm} = AuctionSupervisor.renew_auction(renew_cloned_auction)
		assert renewed_cloned_fsm.state == :started
		assert renewed_cloned_fsm.data.ticker_ref != nil
		assert renewed_cloned_fsm.data.cloned_to_auction_id == nil
		assert renewed_cloned_fsm.data.cloned_from_auction_id == still_closed_fsm.data.auction_id
		assert renewed_cloned_fsm.data.is_sold == false
		assert renewed_cloned_fsm.data.closed_by == nil
		assert renewed_cloned_fsm.data.stock == create_auction.stock
		assert renewed_cloned_fsm.data.original_stock == create_auction.stock
		assert renewed_cloned_fsm.data.renewal_count == closed_cloned_fsm.data.renewal_count+1
		assert length(renewed_cloned_fsm.data.bids) == 0
	end

	test "It should succeed when RENEWING an auction (case of VP/w/RP/wo/AR auction, BP < RP, NOT SOLD, NOT CLONED) closed with bids, CLONED, SCHEDULED then STARTED", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+1,
																		time_extension: false,
																		start_price: 1.00,
																		reserve_price: 2.00,
																		automatic_renewal: false,
																		stock: 1}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		place_bid = %PlaceBid{auction_id: started_fsm.data.auction_id,
													bidder_id: context[:buyer_id_a], 
													bidder_name: "rapanui", 
													requested_qty: 1,
													max_value: 1.00}

		{:ok, _event, bid_placed_fsm} = AuctionSupervisor.place_bid(place_bid)
		assert length(bid_placed_fsm.data.bids) == 1
		assert bid_placed_fsm.data.current_price == 1.00
		assert hd(bid_placed_fsm.data.bids).bidder_id == place_bid.bidder_id
		assert hd(bid_placed_fsm.data.bids).time_extended == false
		assert bid_placed_fsm.data.end_date_time == create_auction.end_date_time

		wait_for_the_end(bid_placed_fsm.data.end_date_time)

		{:ok, closed_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)
		assert closed_fsm.state == :closed
		assert closed_fsm.data.cloned_to_auction_id == nil
		assert closed_fsm.data.is_sold == false
		assert closed_fsm.data.closed_by != nil
		assert closed_fsm.data.stock == create_auction.stock
		assert closed_fsm.data.original_stock == create_auction.stock

		renew_auction = %RenewAuction{auction_id: closed_fsm.data.auction_id,
																	renewed_by: UserEvent.get_renewed_by_system,
																	start_date_time: now()+2,
																	end_date_time: nil,
																	created_at: now()}
		{:ok, _event, renewed_fsm} = AuctionSupervisor.renew_auction(renew_auction)
		# Checks that the auction is still CLOSED
		assert renewed_fsm.state == :closed
		assert renewed_fsm.data.cloned_to_auction_id != nil
		assert renewed_fsm.data.is_sold == false
		assert renewed_fsm.data.closed_by != nil
		assert renewed_fsm.data.stock == 0
		assert renewed_fsm.data.original_stock == create_auction.stock

		# Checks that the CLONED auction is SCHEDULED
		{:ok, cloned_scheduled_fsm} = AuctionSupervisor.get_auction(renewed_fsm.data.cloned_to_auction_id, true)
		assert cloned_scheduled_fsm.state == :scheduled
		assert cloned_scheduled_fsm.data.ticker_ref != nil
		assert cloned_scheduled_fsm.data.cloned_to_auction_id == nil
		assert cloned_scheduled_fsm.data.cloned_from_auction_id == renewed_fsm.data.auction_id
		assert cloned_scheduled_fsm.data.is_sold == false
		assert cloned_scheduled_fsm.data.closed_by == nil
		assert cloned_scheduled_fsm.data.stock == create_auction.stock
		assert cloned_scheduled_fsm.data.original_stock == create_auction.stock
		assert length(cloned_scheduled_fsm.data.bids) == 0

		# Waits for the CLONED and SCHEDULED auction to start
		wait_for_the_end(cloned_scheduled_fsm.data.start_date_time)

		# Checks that the CLONED and SCHEDULED auction is now STARTED
		{:ok, cloned_started_fsm} = AuctionSupervisor.get_auction(renewed_fsm.data.cloned_to_auction_id, true)
		assert cloned_started_fsm.state == :started
		assert cloned_started_fsm.data.ticker_ref != nil
		assert cloned_started_fsm.data.cloned_to_auction_id == nil
		assert cloned_started_fsm.data.cloned_from_auction_id == renewed_fsm.data.auction_id
		assert cloned_started_fsm.data.is_sold == false
		assert cloned_started_fsm.data.closed_by == nil
		assert cloned_started_fsm.data.stock == create_auction.stock
		assert cloned_started_fsm.data.original_stock == create_auction.stock
		assert cloned_started_fsm.data.renewal_count == closed_fsm.data.renewal_count+1
		assert length(cloned_started_fsm.data.bids) == 0
	end

	test "It should succeed when RENEWING an auction (case of VP/w/RP/wo/AR auction, NOT SOLD, NOT CLONED) closed without bids, NOT CLONED, STARTED", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+1,
																		time_extension: false,
																		start_price: 1.00,
																		reserve_price: 2.00,
																		automatic_renewal: false,
																		stock: 1}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		wait_for_the_end(started_fsm.data.end_date_time)

		{:ok, closed_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)
		assert closed_fsm.state == :closed
		assert closed_fsm.data.cloned_to_auction_id == nil
		assert closed_fsm.data.is_sold == false
		assert closed_fsm.data.closed_by != nil
		assert closed_fsm.data.stock == create_auction.stock
		assert closed_fsm.data.original_stock == create_auction.stock

		renew_auction = %RenewAuction{auction_id: closed_fsm.data.auction_id,
																	renewed_by: UserEvent.get_renewed_by_system,
																	start_date_time: now(),
																	end_date_time: nil,
																	created_at: now()}
		{:ok, _event, renewed_fsm} = AuctionSupervisor.renew_auction(renew_auction)

		assert renewed_fsm.state == :started
		assert renewed_fsm.data.ticker_ref != nil
		assert renewed_fsm.data.cloned_to_auction_id == nil
		assert renewed_fsm.data.is_sold == false
		assert renewed_fsm.data.closed_by == nil
		assert renewed_fsm.data.stock == create_auction.stock
		assert renewed_fsm.data.original_stock == create_auction.stock
		assert renewed_fsm.data.renewal_count == closed_fsm.data.renewal_count+1
	end

	test "It should succeed when RENEWING an auction (case of VP/w/RP/wo/AR auction, NOT SOLD, NOT CLONED) closed without bids, NOT CLONED, SCHEDULED then STARTED", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+1,
																		time_extension: false,
																		start_price: 1.00,
																		reserve_price: 2.00,
																		automatic_renewal: false,
																		stock: 1}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		wait_for_the_end(started_fsm.data.end_date_time)

		{:ok, closed_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)
		assert closed_fsm.state == :closed
		assert closed_fsm.data.cloned_to_auction_id == nil
		assert closed_fsm.data.is_sold == false
		assert closed_fsm.data.closed_by != nil
		assert closed_fsm.data.stock == create_auction.stock
		assert closed_fsm.data.original_stock == create_auction.stock

		renew_auction = %RenewAuction{auction_id: closed_fsm.data.auction_id,
																	renewed_by: UserEvent.get_renewed_by_system,
																	start_date_time: now()+2,
																	end_date_time: nil,
																	created_at: now()}
		{:ok, _event, renewed_scheduled_fsm} = AuctionSupervisor.renew_auction(renew_auction)

		assert renewed_scheduled_fsm.state == :scheduled
		assert renewed_scheduled_fsm.data.ticker_ref != nil
		assert renewed_scheduled_fsm.data.cloned_to_auction_id == nil
		assert renewed_scheduled_fsm.data.cloned_from_auction_id == nil
		assert renewed_scheduled_fsm.data.is_sold == false
		assert renewed_scheduled_fsm.data.closed_by == nil
		assert renewed_scheduled_fsm.data.stock == create_auction.stock
		assert renewed_scheduled_fsm.data.original_stock == create_auction.stock

		# Waits for the RENEWED and SCHEDULED auction to start
		wait_for_the_end(renewed_scheduled_fsm.data.start_date_time)

		# Checks that the RENEWED and SCHEDULED auction is now STARTED
		{:ok, renewed_started_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)
		assert renewed_started_fsm.state == :started
		assert renewed_started_fsm.data.ticker_ref != nil
		assert renewed_started_fsm.data.cloned_to_auction_id == nil
		assert renewed_started_fsm.data.cloned_from_auction_id == nil
		assert renewed_started_fsm.data.is_sold == false
		assert renewed_started_fsm.data.closed_by == nil
		assert renewed_started_fsm.data.stock == create_auction.stock
		assert renewed_started_fsm.data.original_stock == create_auction.stock
		assert length(renewed_started_fsm.data.bids) == 0
	end

	test "It should succeed when placing ONE bid on a VP/w/RP/w/AR auction, BP < RP, NOT SOLD, CLONED", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+1,
																		time_extension: false,
																		start_price: 1.00,
																		reserve_price: 2.00,
																		automatic_renewal: true,
																		stock: 1}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		place_bid = %PlaceBid{auction_id: started_fsm.data.auction_id,
													bidder_id: context[:buyer_id_a], 
													bidder_name: "rapanui", 
													requested_qty: 1,
													max_value: 1.00}

		{:ok, _event, bid_placed_fsm} = AuctionSupervisor.place_bid(place_bid)
		assert length(bid_placed_fsm.data.bids) == 1
		assert bid_placed_fsm.data.current_price == 1.00
		assert hd(bid_placed_fsm.data.bids).bidder_id == place_bid.bidder_id
		assert hd(bid_placed_fsm.data.bids).time_extended == false
		assert bid_placed_fsm.data.end_date_time == create_auction.end_date_time

		wait_for_the_end(bid_placed_fsm.data.end_date_time)

		# Check the closed auction
		{:ok, closed_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)
		assert closed_fsm.state == :closed
		assert closed_fsm.data.cloned_to_auction_id != nil
		assert closed_fsm.data.is_sold == false
		assert closed_fsm.data.closed_by != nil
		assert length(closed_fsm.data.bids) == 1

		# Check the cloned auction
		{:ok, cloned_fsm} = AuctionSupervisor.get_auction(closed_fsm.data.cloned_to_auction_id, true)
		assert cloned_fsm.state == :started
		assert cloned_fsm.data.cloned_to_auction_id == nil
		assert cloned_fsm.data.cloned_from_auction_id == closed_fsm.data.auction_id
		assert cloned_fsm.data.is_sold == false
		assert cloned_fsm.data.closed_by == nil
		assert cloned_fsm.data.start_price == closed_fsm.data.start_price
		assert cloned_fsm.data.current_price == cloned_fsm.data.start_price
		assert cloned_fsm.data.stock == closed_fsm.data.stock
		assert cloned_fsm.data.original_stock == closed_fsm.data.original_stock
		assert length(cloned_fsm.data.bids) == 0
		assert cloned_fsm.data.renewal_count == closed_fsm.data.renewal_count+1
	end

	test "It should succeed when placing ONE bid on a VP/w/RP/STOCK = 1 auction, BP >= RP, SOLD, NOT CLONED", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+1,
																		time_extension: false,
																		start_price: 1.00,
																		reserve_price: 2.00,
																		automatic_renewal: true,
																		stock: 1}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		place_bid = %PlaceBid{auction_id: started_fsm.data.auction_id,
													bidder_id: context[:buyer_id_a], 
													bidder_name: "rapanui", 
													requested_qty: 1,
													max_value: 2.40}

		{:ok, _event, bid_placed_fsm} = AuctionSupervisor.place_bid(place_bid)
		assert length(bid_placed_fsm.data.bids) == 1
		assert bid_placed_fsm.data.current_price == create_auction.reserve_price
		assert hd(bid_placed_fsm.data.bids).bidder_id == place_bid.bidder_id
		assert hd(bid_placed_fsm.data.bids).time_extended == false
		assert bid_placed_fsm.data.end_date_time == create_auction.end_date_time

		wait_for_the_end(bid_placed_fsm.data.end_date_time)

		# Check the closed auction
		{:ok, sold_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)
		assert sold_fsm.state == :sold
		assert sold_fsm.data.cloned_to_auction_id == nil
		assert sold_fsm.data.is_sold == true
		assert sold_fsm.data.closed_by != nil
		assert sold_fsm.data.stock == 0
		assert sold_fsm.data.original_stock == 1
		assert length(sold_fsm.data.bids) == 1
		assert sold_fsm.data.current_price == create_auction.reserve_price
	end

	test "It should succeed when placing MULTIPLE bids on a VP/wo/RP/STOCK = 1 auction, SOLD, NOT CLONED (Case #1)", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+1,
																		time_extension: false,
																		start_price: 1.00,
																		automatic_renewal: true,
																		stock: 1}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		#
		#
		#
		# Auction -----		Bid ---------------		|		Auction -----		Bid list ----------------------------------
		# current_price 	bidder 		max_value 	|		current_price 	bidder 		value 	max_value		auto 	visible
		# =====================================================================================================
		# 1.00						buyer_a		2.00				|		1.00						buyer_a		1.00		2.00				N 		O
		# -----------------------------------------------------------------------------------------------------
		# 1.00						buyer_b		1.30				|		1.30						buyer_a		1.30		2.00				O 		O
		#																				|										buyer_b		1.30 		1.30 				N 		O
		#																				|										buyer_a		1.00		2.00				N 		O
		# buyer_a raises its max bid --------------------------------------------------------------------------
		# 1.30						buyer_a		3.00				|		1.30						buyer_a		1.30		3.00				N 		N
		#																				|										buyer_a		1.30 		2.00 				O 		O
		#																				|										buyer_b		1.30 		1.30 				N 		O
		#																				|										buyer_a		1.00		2.00				N 		O
		# -----------------------------------------------------------------------------------------------------
		# 1.30						buyer_c		2.50				|		2.50						buyer_a		2.50		3.00				O 		O
		#																				|										buyer_c		2.50 		2.50 				N 		O
		#																				|										buyer_a		1.30 		3.00 				N 		N
		#																				|										buyer_a		1.30 		2.00 				O 		O
		#																				|										buyer_b		1.30 		1.30 				N 		O
		#																				|										buyer_a		1.00		2.00				N 		O
		# -----------------------------------------------------------------------------------------------------
		# 1.30						buyer_b		3.00				|		3.00						buyer_a		3.00		3.00				O 		O
		#																				|										buyer_b		3.00 		3.00 				N 		O
		#																				|										buyer_c		2.50 		2.50 				N 		O
		#																				|										buyer_a		1.30 		3.00 				N 		N
		#																				|										buyer_a		1.30 		2.00 				O 		O
		#																				|										buyer_b		1.30 		1.30 				N 		O
		#																				|										buyer_a		1.00		2.00				N 		O		
		bids = [
			{context[:buyer_id_a], 2.00}, 
			{context[:buyer_id_b], 1.30},	
			{context[:buyer_id_a], 3.00}, 
			{context[:buyer_id_c], 2.50}, 
			{context[:buyer_id_b], 3.00}
		]

		# The list of bids that is expected when the auction closes
		expected_bids = [
			%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], is_auto: true, is_visible: true, max_value: 3.0, requested_qty: 1, time_extended: false, value: 3.0},
		 	%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_b], is_auto: false, is_visible: true, max_value: 3.0, requested_qty: 1, time_extended: false, value: 3.0},
 			%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], is_auto: true, is_visible: true, max_value: 3.0, requested_qty: 1, time_extended: false, value: 2.5},
 			%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_c], is_auto: false, is_visible: true, max_value: 2.5, requested_qty: 1, time_extended: false, value: 2.5},
 			%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], is_auto: false, is_visible: false, max_value: 3.0, requested_qty: 1, time_extended: false, value: 1.3},
 			%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], is_auto: true, is_visible: true, max_value: 2.0, requested_qty: 1, time_extended: false, value: 1.3},
 			%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_b], is_auto: false, is_visible: true, max_value: 1.3, requested_qty: 1, time_extended: false, value: 1.3},
 			%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], is_auto: false, is_visible: true, max_value: 2.0, requested_qty: 1, time_extended: false, value: 1.0}
 		]

 		# Place the bids
		for {bidder_id, max_value} <- bids do
			bid_command = %PlaceBid{auction_id: started_fsm.data.auction_id,
															bidder_id: bidder_id,
															requested_qty: 1,
															max_value: max_value,
															created_at: now()}
			assert {:ok, _event, bid_placed_fsm} = AuctionSupervisor.place_bid(bid_command)
		end

		#
		wait_for_the_end(started_fsm.data.end_date_time)

		#
		{:ok, sold_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)

		# Make a list of bids without the created_at and bidder_name keys
		cleaned_bids = Enum.map(sold_fsm.data.bids, fn(b) -> Map.delete(b, :created_at) |> Map.delete(:bidder_name) end)

		assert sold_fsm.state == :sold
		assert sold_fsm.data.cloned_to_auction_id == nil
		assert sold_fsm.data.is_sold == true
		assert sold_fsm.data.closed_by != nil
		assert sold_fsm.data.stock == 0
		assert sold_fsm.data.original_stock == 1
		assert cleaned_bids == expected_bids
	end

	test "It should succeed when placing MULTIPLE bids on a VP/wo/RP/STOCK = 1 auction, SOLD, NOT CLONED (Case #2)", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+1,
																		time_extension: false,
																		start_price: 1.00,
																		automatic_renewal: true,
																		stock: 1}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		# Auction -----		Bid ---------------		|		Auction -----		Bid list ----------------------------------
		# current_price 	bidder 		max_value 	|		current_price 	bidder 		value 	max_value		auto 	visible
		# =====================================================================================================
		# 1.00						buyer_a		0.50		R		|		1.00						
		# -----------------------------------------------------------------------------------------------------
		# 1.00						buyer_a		1.00				|		1.00						buyer_a		1.00		1.00				N 		O
		# -----------------------------------------------------------------------------------------------------
		# 1.00						buyer_b		0.50		R		|		1.00						buyer_a		1.00		1.00				N 		O
		# -----------------------------------------------------------------------------------------------------
		# 1.00						buyer_b		1.00		R		|		1.00						buyer_a		1.00		1.00				N 		O
		#		
		bids = [
			{context[:buyer_id_a], 0.50, :error},
			{context[:buyer_id_a], 1.00, :ok},	
			{context[:buyer_id_b], 0.50, :error}, 
			{context[:buyer_id_b], 1.00, :error}
		]

		# The list of bids that is expected when the auction closes
		expected_bids = [
			%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], is_auto: false, is_visible: true, max_value: 1.0, requested_qty: 1, time_extended: false, value: 1.0}
 		]

 		# Place the bids
		for {bidder_id, max_value, expected_status} <- bids do
			bid_command = %PlaceBid{auction_id: started_fsm.data.auction_id,
															bidder_id: bidder_id,
															requested_qty: 1,
															max_value: max_value,
															created_at: now()}
			{^expected_status, _event, bid_placed_fsm} = AuctionSupervisor.place_bid(bid_command)
		end

		#
		wait_for_the_end(started_fsm.data.end_date_time)

		#
		{:ok, sold_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)

		# Make a list of bids without the created_at and bidder_name keys
		cleaned_bids = Enum.map(sold_fsm.data.bids, fn(b) -> Map.delete(b, :created_at) |> Map.delete(:bidder_name) end)

		assert sold_fsm.state == :sold
		assert sold_fsm.data.cloned_to_auction_id == nil
		assert sold_fsm.data.is_sold == true
		assert sold_fsm.data.closed_by != nil
		assert sold_fsm.data.stock == 0
		assert sold_fsm.data.original_stock == 1
		assert cleaned_bids == expected_bids
	end

	test "It should succeed when placing MULTIPLE bids on a VP/w/RP/wo/AR/STOCK = 1 auction, NOT SOLD, NOT CLONED (Case #3)", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+1,
																		time_extension: false,
																		start_price: 1.00,
																		reserve_price: 8.00,
																		automatic_renewal: false,
																		stock: 1}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		# Auction -----		Bid ---------------		|		Auction -----		Bid list ----------------------------------
		# current_price 	bidder 		max_value 	|		current_price 	bidder 		value 	max_value		auto 	visible
		# =====================================================================================================
		# 1.00						buyer_a		0.50		R		|		1.00						
		# -----------------------------------------------------------------------------------------------------
		# 1.00						buyer_a		1.00				|		1.00						buyer_a		1.00		1.00				N 		O
		# -----------------------------------------------------------------------------------------------------
		# 1.00						buyer_b		2.00				|		1.10						buyer_b		1.10		2.00				N 		O
		# 																			|										buyer_a		1.00		1.00				N 		O
		# -----------------------------------------------------------------------------------------------------
		# 1.10						buyer_a		1.10		R		|		1.10						buyer_b		1.10		2.00				N 		O
		# 																			|										buyer_a		1.00		1.00				N 		O
		#
		bids = [
			{context[:buyer_id_a], 0.50, {:error, %BidRejected{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], max_value: 0.5, reason: :bid_below_allowed_min, requested_qty: 1}}},
			{context[:buyer_id_a], 1.00, {:ok, 		%BidPlaced{auction_id: started_fsm.data.auction_id, 	bidder_id: context[:buyer_id_a], max_value: 1.0, requested_qty: 1}}},	
			{context[:buyer_id_b], 2.00, {:ok, 		%BidPlaced{auction_id: started_fsm.data.auction_id, 	bidder_id: context[:buyer_id_b], max_value: 2.0, requested_qty: 1}}}, 
			{context[:buyer_id_a], 1.10, {:error, %BidRejected{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], max_value: 1.1, reason: :bid_below_allowed_min, requested_qty: 1}}}
		]

		# The list of bids that is expected when the auction closes
		expected_bids = [
			%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_b], is_auto: false, is_visible: true, max_value: 2.0, requested_qty: 1, time_extended: false, value: 1.10},
			%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], is_auto: false, is_visible: true, max_value: 1.0, requested_qty: 1, time_extended: false, value: 1.00}
 		]

 		# Place the bids
		for {bidder_id, max_value, {expected_status, expected_event}} <- bids do
			bid_command = %PlaceBid{auction_id: started_fsm.data.auction_id,
															bidder_id: bidder_id,
															requested_qty: 1,
															max_value: max_value,
															created_at: now()}
			{^expected_status, event, bid_placed_fsm} = AuctionSupervisor.place_bid(bid_command)
			assert Map.delete(event, :created_at) == Map.delete(expected_event, :created_at)
		end

		#
		wait_for_the_end(started_fsm.data.end_date_time)

		#
		{:ok, closed_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)

		# Make a list of bids without the created_at and bidder_name keys
		cleaned_bids = Enum.map(closed_fsm.data.bids, fn(b) -> Map.delete(b, :created_at) |> Map.delete(:bidder_name) end)

		assert closed_fsm.state == :closed
		assert closed_fsm.data.cloned_to_auction_id == nil
		assert closed_fsm.data.is_sold == false
		assert closed_fsm.data.closed_by != nil
		assert closed_fsm.data.stock == 1
		assert closed_fsm.data.original_stock == 1
		assert cleaned_bids == expected_bids
	end

	test "It should succeed when placing MULTIPLE bids on a VP/w/RP/wo/AR/STOCK = 1 auction, NOT SOLD, NOT CLONED (Case #4)", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+1,
																		time_extension: false,
																		start_price: 1.00,
																		reserve_price: 8.00,
																		automatic_renewal: false,
																		stock: 1}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		# Auction -----		Bid ---------------		|		Auction -----		Bid list ----------------------------------
		# current_price 	bidder 		max_value 	|		current_price 	bidder 		value 	max_value		auto 	visible
		# =====================================================================================================
		# 1.00						buyer_a		0.50		R		|		1.00						
		# -----------------------------------------------------------------------------------------------------
		# 1.00						buyer_a		8.00				|		8.00						buyer_a		8.00		8.00				N 		O
		#		
		bids = [
			{context[:buyer_id_a], 0.50, {:error, %BidRejected{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], max_value: 0.5, reason: :bid_below_allowed_min, requested_qty: 1}}},
			{context[:buyer_id_a], 8.00, {:ok, %BidPlaced{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], max_value: 8.0, requested_qty: 1}}}
		]

		# The list of bids that is expected when the auction closes
		expected_bids = [
			%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], is_auto: false, is_visible: true, max_value: 8.0, requested_qty: 1, time_extended: false, value: 8.00}
 		]

 		# Place the bids
		for {bidder_id, max_value, {expected_status, expected_event}} <- bids do
			bid_command = %PlaceBid{auction_id: started_fsm.data.auction_id,
															bidder_id: bidder_id,
															requested_qty: 1,
															max_value: max_value,
															created_at: now()}
			{^expected_status, event, bid_placed_fsm} = AuctionSupervisor.place_bid(bid_command)
			assert Map.delete(event, :created_at) == Map.delete(expected_event, :created_at)
		end

		#
		wait_for_the_end(started_fsm.data.end_date_time)

		#
		{:ok, sold_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)

		# Make a list of bids without the created_at and bidder_name keys
		cleaned_bids = Enum.map(sold_fsm.data.bids, fn(b) -> Map.delete(b, :created_at) |> Map.delete(:bidder_name) end)

		assert sold_fsm.state == :sold
		assert sold_fsm.data.cloned_to_auction_id == nil
		assert sold_fsm.data.is_sold == true
		assert sold_fsm.data.closed_by != nil
		assert sold_fsm.data.stock == 0
		assert sold_fsm.data.original_stock == 1
		assert cleaned_bids == expected_bids
	end

	test "It should succeed when placing MULTIPLE bids on a VP/w/RP/wo/AR/STOCK = 1 auction, NOT SOLD, NOT CLONED (Case #5)", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+1,
																		time_extension: false,
																		start_price: 1.00,
																		reserve_price: 8.00,
																		automatic_renewal: false,
																		stock: 1}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		# Auction -----		Bid ---------------		|		Auction -----		Bid list ----------------------------------
		# current_price 	bidder 		max_value 	|		current_price 	bidder 		value 	max_value		auto 	visible
		# =====================================================================================================
		# 1.00						buyer_a		0.50		R		|		1.00						
		# -----------------------------------------------------------------------------------------------------
		# 1.00						buyer_a		8.00				|		8.00						buyer_a		8.00		8.00				N 		O
		# -----------------------------------------------------------------------------------------------------
		# 8.00						buyer_a		9.00				|		8.00						buyer_a		8.00		9.00				N 		N
		# 																			|										buyer_a		8.00		8.00				N 		O
		#		
		bids = [
			{context[:buyer_id_a], 0.50, {:error, %BidRejected{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], max_value: 0.5, reason: :bid_below_allowed_min, requested_qty: 1}}},
			{context[:buyer_id_a], 8.00, {:ok, %BidPlaced{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], max_value: 8.0, requested_qty: 1}}},
			{context[:buyer_id_a], 9.00, {:ok, %BidPlaced{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], max_value: 9.0, requested_qty: 1}}}
		]

		# The list of bids that is expected when the auction closes
		expected_bids = [
			%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], is_auto: false, is_visible: false, max_value: 9.0, requested_qty: 1, time_extended: false, value: 8.00},
			%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], is_auto: false, is_visible: true, max_value: 8.0, requested_qty: 1, time_extended: false, value: 8.00}
 		]

 		# Place the bids
		for {bidder_id, max_value, {expected_status, expected_event}} <- bids do
			bid_command = %PlaceBid{auction_id: started_fsm.data.auction_id,
															bidder_id: bidder_id,
															requested_qty: 1,
															max_value: max_value,
															created_at: now()}
			{^expected_status, event, bid_placed_fsm} = AuctionSupervisor.place_bid(bid_command)
			assert Map.delete(event, :created_at) == Map.delete(expected_event, :created_at)
		end

		#
		wait_for_the_end(started_fsm.data.end_date_time)

		#
		{:ok, sold_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)

		# Make a list of bids without the created_at and bidder_name keys
		cleaned_bids = Enum.map(sold_fsm.data.bids, fn(b) -> Map.delete(b, :created_at) |> Map.delete(:bidder_name) end)

		assert sold_fsm.state == :sold
		assert sold_fsm.data.cloned_to_auction_id == nil
		assert sold_fsm.data.is_sold == true
		assert sold_fsm.data.closed_by != nil
		assert sold_fsm.data.stock == 0
		assert sold_fsm.data.original_stock == 1
		assert cleaned_bids == expected_bids
	end

	test "It should succeed when placing MULTIPLE bids on a VP/w/RP/wo/AR/STOCK = 1 auction, NOT SOLD, NOT CLONED (Case #6)", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+1,
																		time_extension: false,
																		start_price: 1.00,
																		reserve_price: 8.00,
																		automatic_renewal: false,
																		stock: 1}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		# Auction -----		Bid ---------------		|		Auction -----		Bid list ----------------------------------
		# current_price 	bidder 		max_value 	|		current_price 	bidder 		value 	max_value		auto 	visible
		# =====================================================================================================
		# 1.00						buyer_a		0.50		R		|		1.00						
		# -----------------------------------------------------------------------------------------------------
		# 1.00						buyer_a		1.00				|		1.00						buyer_a		1.00		1.00				N 		O
		# -----------------------------------------------------------------------------------------------------
		# 1.00						buyer_a		8.00				|		8.00						buyer_a		8.00		8.00				N 		O
		# 																			|										buyer_a		1.00		1.00				N 		O
		#		
		bids = [
			{context[:buyer_id_a], 0.50, {:error, %BidRejected{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], max_value: 0.5, reason: :bid_below_allowed_min, requested_qty: 1}}},
			{context[:buyer_id_a], 1.00, {:ok, %BidPlaced{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], max_value: 1.0, requested_qty: 1}}},
			{context[:buyer_id_a], 9.00, {:ok, %BidPlaced{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], max_value: 9.0, requested_qty: 1}}}
		]

		# The list of bids that is expected when the auction closes
		expected_bids = [
			%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], is_auto: false, is_visible: true, max_value: 9.0, requested_qty: 1, time_extended: false, value: 8.00},
			%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], is_auto: false, is_visible: true, max_value: 1.0, requested_qty: 1, time_extended: false, value: 1.00}
 		]

 		# Place the bids
		for {bidder_id, max_value, {expected_status, expected_event}} <- bids do
			bid_command = %PlaceBid{auction_id: started_fsm.data.auction_id,
															bidder_id: bidder_id,
															requested_qty: 1,
															max_value: max_value,
															created_at: now()}
			{^expected_status, event, bid_placed_fsm} = AuctionSupervisor.place_bid(bid_command)
			assert Map.delete(event, :created_at) == Map.delete(expected_event, :created_at)
		end

		#
		wait_for_the_end(started_fsm.data.end_date_time)

		#
		{:ok, sold_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)

		# Make a list of bids without the created_at and bidder_name keys
		cleaned_bids = Enum.map(sold_fsm.data.bids, fn(b) -> Map.delete(b, :created_at) |> Map.delete(:bidder_name) end)

		assert sold_fsm.state == :sold
		assert sold_fsm.data.cloned_to_auction_id == nil
		assert sold_fsm.data.is_sold == true
		assert sold_fsm.data.closed_by != nil
		assert sold_fsm.data.stock == 0
		assert sold_fsm.data.original_stock == 1
		assert cleaned_bids == expected_bids
	end

	test "It should succeed when placing MULTIPLE bids on a VP/w/RP/wo/AR/STOCK = 1 auction, NOT SOLD, NOT CLONED (Case #7)", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 1,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+1,
																		time_extension: false,
																		start_price: 1.00,
																		reserve_price: 8.00,
																		automatic_renewal: false,
																		stock: 1}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		# Auction -----		Bid ---------------		|		Auction -----		Bid list ----------------------------------
		# current_price 	bidder 		max_value 	|		current_price 	bidder 		value 	max_value		auto 	visible
		# =====================================================================================================
		# 1.00						buyer_a		0.50		R		|		1.00						
		# -----------------------------------------------------------------------------------------------------
		# 1.00						buyer_a		1.00				|		1.00						buyer_a		1.00		1.00				N 		O
		# -----------------------------------------------------------------------------------------------------
		# 1.00						buyer_a		7.00				|		1.00						buyer_a		1.00		7.00				N 		N
		# 																			|										buyer_a		1.00		1.00				N 		O
		# -----------------------------------------------------------------------------------------------------
		# 1.00						buyer_a		9.00				|		8.00						buyer_a		8.00		9.00				N 		O
		# 																			|										buyer_a		1.00		7.00				N 		N
		# 																			|										buyer_a		1.00		1.00				N 		O
		# -----------------------------------------------------------------------------------------------------
		# 8.00						buyer_a		10.00				|		8.00						buyer_a		8.00		10.00				N 		N
		# 																			|										buyer_a		8.00		9.00				N 		O
		# 																			|										buyer_a		1.00		7.00				N 		N
		# 																			|										buyer_a		1.00		1.00				N 		O
		#		
		bids = [
			{context[:buyer_id_a], 0.50, {:error, %BidRejected{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], max_value: 0.5, reason: :bid_below_allowed_min, requested_qty: 1}}},
			{context[:buyer_id_a], 1.00, {:ok, %BidPlaced{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], max_value: 1.0, requested_qty: 1}}},
			{context[:buyer_id_a], 7.00, {:ok, %BidPlaced{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], max_value: 7.0, requested_qty: 1}}},
			{context[:buyer_id_a], 9.00, {:ok, %BidPlaced{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], max_value: 9.0, requested_qty: 1}}},
			{context[:buyer_id_a], 10.00, {:ok, %BidPlaced{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], max_value: 10.0, requested_qty: 1}}}
		]

		# The list of bids that is expected when the auction closes
		expected_bids = [
			%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], is_auto: false, is_visible: false, max_value: 10.0, requested_qty: 1, time_extended: false, value: 8.00},
			%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], is_auto: false, is_visible: true, max_value: 9.0, requested_qty: 1, time_extended: false, value: 8.00},
			%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], is_auto: false, is_visible: false, max_value: 7.0, requested_qty: 1, time_extended: false, value: 1.00},
			%{auction_id: started_fsm.data.auction_id, bidder_id: context[:buyer_id_a], is_auto: false, is_visible: true, max_value: 1.0, requested_qty: 1, time_extended: false, value: 1.00}
 		]

 		# Place the bids
		for {bidder_id, max_value, {expected_status, expected_event}} <- bids do
			bid_command = %PlaceBid{auction_id: started_fsm.data.auction_id,
															bidder_id: bidder_id,
															requested_qty: 1,
															max_value: max_value,
															created_at: now()}
			{^expected_status, event, bid_placed_fsm} = AuctionSupervisor.place_bid(bid_command)
			assert Map.delete(event, :created_at) == Map.delete(expected_event, :created_at)
		end

		#
		wait_for_the_end(started_fsm.data.end_date_time)

		#
		{:ok, sold_fsm} = AuctionSupervisor.get_auction(started_fsm.data.auction_id, true)

		# Make a list of bids without the created_at and bidder_name keys
		cleaned_bids = Enum.map(sold_fsm.data.bids, fn(b) -> Map.delete(b, :created_at) |> Map.delete(:bidder_name) end)

		assert sold_fsm.state == :sold
		assert sold_fsm.data.cloned_to_auction_id == nil
		assert sold_fsm.data.is_sold == true
		assert sold_fsm.data.closed_by != nil
		assert sold_fsm.data.stock == 0
		assert sold_fsm.data.original_stock == 1
		assert cleaned_bids == expected_bids
	end

	test "It should succeed when placing a bid on a FP auction for the full stock, SOLD, NOT CLONED", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+3600, 
																		start_price: 1.00,
																		stock: 6}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		place_bid = %PlaceBid{auction_id: started_fsm.data.auction_id,
													bidder_id: context[:buyer_id_a], 
													bidder_name: "rapanui", 
													requested_qty: 6,
													max_value: 1.00}

		{:ok, _event, bid_placed_fsm} = AuctionSupervisor.place_bid(place_bid)
		assert bid_placed_fsm.state == :sold
		assert bid_placed_fsm.data.is_sold == true
		assert bid_placed_fsm.data.closed_by != nil
		assert bid_placed_fsm.data.cloned_to_auction_id == nil
		assert bid_placed_fsm.data.cloned_from_auction_id == nil
		assert bid_placed_fsm.data.current_price == create_auction.start_price
		assert bid_placed_fsm.data.stock == 0
		assert bid_placed_fsm.data.original_stock == create_auction.stock
		assert length(bid_placed_fsm.data.bids) == 1
		assert hd(bid_placed_fsm.data.bids).bidder_id == place_bid.bidder_id
	end

	test "It should succeed when placing a bid on a FP auction for part of the stock, SOLD, CLONED", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+3600, 
																		start_price: 1.00,
																		stock: 6}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		place_bid = %PlaceBid{auction_id: started_fsm.data.auction_id,
													bidder_id: context[:buyer_id_a], 
													bidder_name: "rapanui", 
													requested_qty: 2,
													max_value: 1.00}

		{:ok, _event, bid_placed_fsm} = AuctionSupervisor.place_bid(place_bid)
		assert bid_placed_fsm.state == :sold
		assert bid_placed_fsm.data.is_sold == true
		assert bid_placed_fsm.data.closed_by != nil
		assert bid_placed_fsm.data.cloned_to_auction_id != nil
		assert bid_placed_fsm.data.cloned_from_auction_id == nil
		assert bid_placed_fsm.data.current_price == create_auction.start_price
		assert bid_placed_fsm.data.stock == 0
		assert bid_placed_fsm.data.original_stock == place_bid.requested_qty
		assert length(bid_placed_fsm.data.bids) == 1
		assert hd(bid_placed_fsm.data.bids).bidder_id == place_bid.bidder_id

		{:ok, cloned_fsm} = AuctionSupervisor.get_auction(bid_placed_fsm.data.cloned_to_auction_id, true)
		assert cloned_fsm.state == :started
		assert cloned_fsm.data.original_stock == started_fsm.data.original_stock - place_bid.requested_qty
		assert cloned_fsm.data.stock == started_fsm.data.original_stock - place_bid.requested_qty
		assert cloned_fsm.data.closed_by == nil
		assert cloned_fsm.data.is_sold == false
		assert cloned_fsm.data.start_price == create_auction.start_price
		assert cloned_fsm.data.current_price == create_auction.start_price
		assert cloned_fsm.data.start_date_time == started_fsm.data.start_date_time
		assert cloned_fsm.data.end_date_time == started_fsm.data.end_date_time
		assert length(cloned_fsm.data.bids) == 0
	end

	test "It should succeed when SUSPENDING then RESUMING a FP/wo/AR auction, NOT CLONED, STARTED then CLOSED", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+3600, 
																		automatic_renewal: false,
																		start_price: 1.00,
																		stock: 6}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		# Suspend the auction
		suspend_auction = %SuspendAuction{auction_id: started_fsm.data.auction_id,
																			suspended_by: UserEvent.get_suspended_by_system}

		{:ok, _event, suspended_fsm} = AuctionSupervisor.suspend_auction(suspend_auction)
		assert suspended_fsm.state == :suspended
		assert suspended_fsm.data.ticker_ref == nil
		assert suspended_fsm.data.is_sold == false
		assert suspended_fsm.data.closed_by == nil
		assert suspended_fsm.data.cloned_to_auction_id == nil
		assert suspended_fsm.data.cloned_from_auction_id == nil
		assert suspended_fsm.data.current_price == create_auction.start_price
		assert suspended_fsm.data.stock == create_auction.stock
		assert suspended_fsm.data.original_stock == create_auction.stock
		assert length(suspended_fsm.data.bids) == 0

		# Resume the auction
		resume_auction = %ResumeAuction{auction_id: started_fsm.data.auction_id,
																		resumed_by: UserEvent.get_resumed_by_system,
																		start_date_time: now(),
																		end_date_time: now()+2,
																		created_at: now()}

		# Resumes an auction and checks that it is started
		{:ok, _event, resumed_fsm} = AuctionSupervisor.resume_auction(resume_auction)
		assert resumed_fsm.state == :started
		assert resumed_fsm.data.ticker_ref != nil
		assert resumed_fsm.data.is_sold == false
		assert resumed_fsm.data.closed_by == nil
		assert resumed_fsm.data.cloned_to_auction_id == nil
		assert resumed_fsm.data.cloned_from_auction_id == nil
		assert resumed_fsm.data.current_price == create_auction.start_price
		assert resumed_fsm.data.stock == create_auction.stock
		assert resumed_fsm.data.original_stock == create_auction.stock
		assert length(resumed_fsm.data.bids) == 0

		# Wait for the resumed auction to end
		wait_for_the_end(resumed_fsm.data.end_date_time)

		# Checks that the resumed auction is now closed
		{:ok, resumed_closed_fsm} = AuctionSupervisor.get_auction(resumed_fsm.data.auction_id, true)
		assert resumed_closed_fsm.state == :closed
		assert resumed_closed_fsm.data.ticker_ref == nil
		assert resumed_closed_fsm.data.is_sold == false
		assert resumed_closed_fsm.data.closed_by != nil
		assert resumed_closed_fsm.data.cloned_to_auction_id == nil
		assert resumed_closed_fsm.data.cloned_from_auction_id == nil
		assert resumed_closed_fsm.data.current_price == create_auction.start_price
		assert resumed_closed_fsm.data.stock == create_auction.stock
		assert resumed_closed_fsm.data.original_stock == create_auction.stock
		assert length(resumed_closed_fsm.data.bids) == 0
	end

	test "It should succeed when SUSPENDING then RESUMING a FP/w/AR auction, NOT CLONED, STARTED then CLOSED", context do
		create_auction = %CreateAuction{auction_id: nil,
																		seller_id: context[:seller_id],
																		sale_type_id: 2,
																		listed_time_id: 1,
																		start_date_time: now, 
																		end_date_time: now+3600, 
																		automatic_renewal: true,
																		start_price: 1.00,
																		stock: 6}

		{:ok, started_fsm} = AuctionSupervisor.create_auction(create_auction)
		assert started_fsm.data.ticker_ref != nil

		# Suspend the auction
		suspend_auction = %SuspendAuction{auction_id: started_fsm.data.auction_id,
																			suspended_by: UserEvent.get_suspended_by_system}

		{:ok, _event, suspended_fsm} = AuctionSupervisor.suspend_auction(suspend_auction)
		assert suspended_fsm.state == :suspended
		assert suspended_fsm.data.ticker_ref == nil
		assert suspended_fsm.data.is_sold == false
		assert suspended_fsm.data.closed_by == nil
		assert suspended_fsm.data.cloned_to_auction_id == nil
		assert suspended_fsm.data.cloned_from_auction_id == nil
		assert suspended_fsm.data.current_price == create_auction.start_price
		assert suspended_fsm.data.stock == create_auction.stock
		assert suspended_fsm.data.original_stock == create_auction.stock
		assert length(suspended_fsm.data.bids) == 0

		# Resume the auction
		resume_auction = %ResumeAuction{auction_id: started_fsm.data.auction_id,
																		resumed_by: UserEvent.get_resumed_by_system,
																		start_date_time: now(),
																		end_date_time: now()+2,
																		created_at: now()}

		# Resumes an auction and checks that it is started
		{:ok, _event, resumed_fsm} = AuctionSupervisor.resume_auction(resume_auction)
		assert resumed_fsm.state == :started
		assert resumed_fsm.data.ticker_ref != nil
		assert resumed_fsm.data.is_sold == false
		assert resumed_fsm.data.closed_by == nil
		assert resumed_fsm.data.cloned_to_auction_id == nil
		assert resumed_fsm.data.cloned_from_auction_id == nil
		assert resumed_fsm.data.current_price == create_auction.start_price
		assert resumed_fsm.data.stock == create_auction.stock
		assert resumed_fsm.data.original_stock == create_auction.stock
		assert length(resumed_fsm.data.bids) == 0

		# Wait for the resumed auction to end
		wait_for_the_end(resumed_fsm.data.end_date_time)

		# Checks that the resumed auction is now closed
		{:ok, resumed_closed_fsm} = AuctionSupervisor.get_auction(resumed_fsm.data.auction_id, true)
		assert resumed_closed_fsm.state == :started
		assert resumed_closed_fsm.data.ticker_ref != nil
		assert resumed_closed_fsm.data.is_sold == false
		assert resumed_closed_fsm.data.closed_by == nil
		assert resumed_closed_fsm.data.cloned_to_auction_id == nil
		assert resumed_closed_fsm.data.cloned_from_auction_id == nil
		assert resumed_closed_fsm.data.current_price == create_auction.start_price
		assert resumed_closed_fsm.data.stock == create_auction.stock
		assert resumed_closed_fsm.data.original_stock == create_auction.stock
		assert length(resumed_closed_fsm.data.bids) == 0
	end

	test "It should succeed when checking the routine that normalizes bid values" do

		# An array of bid value, bid up value, expected normalized value
		values = [
			{0.10, 0.10, 0.10},
			{0.12, 0.10, 0.10},
			{0.14, 0.10, 0.10},
			{0.19, 0.10, 0.10},

			{0.10, 0.05, 0.10},
			{0.14, 0.05, 0.10},
			{0.15, 0.05, 0.15},
			{0.19, 0.05, 0.15},

			{0.01, 0.01, 0.01},

			{0.70, 0.05, 0.70},
			{0.75, 0.05, 0.75},

			{0.70, 0.03, 0.69},

			{1.00, 0.01, 1.00},
			{1.14, 0.10, 1.10},
			{1.19, 0.10, 1.10},
			{1.00, 0.10, 1.00},

			{1000.75, 0.10, 1000.70},
			{1000.99, 1.00, 1000},
		]

		for {value, bid_up, expected_value} <- values do
			assert Andycot.CommandProcessor.Auction.normalize_value(value, bid_up) == expected_value
		end

	end

	@tag :one
	test "It should succeed when calling make_auction_resumed_event" do
		command = %ResumeAuction{ auction_id: 19,
															resumed_by: 260,
															start_date_time: now(),
															end_date_time: now()+3600,
															created_at: now()}
		event = make_auction_resumed_event(command)

		assert command.auction_id 			== event.auction_id
		assert command.resumed_by 			== event.resumed_by
		assert command.start_date_time 	== event.start_date_time
		assert command.end_date_time 		== event.end_date_time
		assert command.created_at 			== event.created_at

		# 		
		sdt = now()+60
		edt = sdt+3600
		overwrite_event = make_auction_resumed_event(command, %{start_date_time: sdt, end_date_time: edt})

		assert command.auction_id 			== event.auction_id
		assert command.resumed_by 			== event.resumed_by
		assert command.start_date_time 	== sdt
		assert command.end_date_time 		== edt
		assert command.created_at 			== event.created_at
	end

	@tag :oneeeeeeeeeeeee
	test "It should succeed when calling make_resume_rejected_event" do
		command = %ResumeAuction{auction_id: 19,
															resumed_by: 260,
															start_date_time: now(),
															end_date_time: now()+3600,
															created_at: now()}
		event = make_resume_rejected_event(command, %{reason: :not_suspended})

		assert command.auction_id 			== event.auction_id
		assert command.resumed_by 			== event.resumed_by
		assert event.reason							== :not_suspended
		assert command.created_at 			== event.created_at
	end

end
