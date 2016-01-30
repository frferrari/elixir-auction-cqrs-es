defmodule Andycot.AuctionVariablePriceStandardTest do
	use ExUnit.Case, async: false
	alias Andycot.AuctionSupervisor
	alias Andycot.UserSupervisor
	import Andycot.Tools.Timestamp
	alias Andycot.Command.User.{RegisterUser, ActivateAccount}
	alias Andycot.Command.Auction.{CreateAuction, PlaceBid, CloseAuction}
	alias Andycot.CommandProcessor.Auction
	alias Andycot.CommandProcessor.AuctionData

	setup_all do
		register_and_activate_user(260, 270, :standard)

		{:ok, [	mode: :standard, 
						sale_type_id: 1, 
						listed_time_id: 1, 
						seller_id: 260, 
						buyer_id: 270,
						vp_create_command: %{	seller_id: 260, 
																	type_id: 1,
																	listed_time_id: 1,												
																	sale_type_id: 1,
																	title: "France UIT 1975",
																	description: "What a strange item",
																	year: 1975,
																	area_id: 310,
																	topic_ids: [120, 275],
																	matched_id: 10000,
																	start_price: 1.00, 
																	currency: "EUR",
																	stock: 1,
																	reserve_price: nil,
																	automatic_renewal: true,
																	time_extension: false,
																	start_date_time: nil,
																	end_date_time: nil
																}
					]}
	end

	#setup context do
	#	:ok
	#end

	def register_and_activate_user(seller_id, buyer_id, mode) when buyer_id < 280 do
		now = now()

		register_seller_command = %{	user_id: seller_id,
																	email: "seller#{seller_id}@myweb.fr",
																	password: "mypassword",
																	algorithm: "sha128",
																	salt: "mysalt",
																	nickname: "mynickname",
																	is_super_admin: "issuperadmin",
																	is_newsletter: "isnewsletter",
																	is_receive_renewals: "isreceiverenewals",
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

		{:ok, fsm} = UserSupervisor.register_user(struct(RegisterUser, register_seller_command), mode)

		UserSupervisor.activate_account(%ActivateAccount{user_id: fsm.data.user_id})

		register_buyer_command = %{	user_id: buyer_id,
																email: "buyer#{buyer_id}@myweb.fr",
																password: "mypassword",
																algorithm: "sha128",
																salt: "mysalt",
																nickname: "mynickname",
																is_super_admin: "issuperadmin",
																is_newsletter: "isnewsletter",
																is_receive_renewals: "isreceiverenewals",
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

		{:ok, fsm} = UserSupervisor.register_user(struct(RegisterUser, register_buyer_command), mode)

		UserSupervisor.activate_account(%ActivateAccount{user_id: fsm.data.user_id})

		register_and_activate_user(seller_id+1, buyer_id+1, mode)
	end

	def register_and_activate_user(_, _, _) do
	end
	
	@tag :one

	test "It should succeed when selling an auction (without reserve price/with time extension) to the higher bidder", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												time_extension: true}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		buyer_a = context[:buyer_id]
		buyer_b = context[:buyer_id]+1

		bids = [%PlaceBid{auction_id: auction_state.auction_id, 
															bidder_id: buyer_a, 
															requested_qty: 1, 
															max_value: 4.00, 
															created_at: now()},
						%PlaceBid{auction_id: auction_state.auction_id, 
															bidder_id: buyer_b, 
															requested_qty: 1, 
															max_value: 2.00,
															created_at: now()}
					]

		for bid_command <- bids do
			assert {:ack, :bid_placed_time_extended} = AuctionSupervisor.place_bid(bid_command, context[:mode])
		end

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == true
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 0
		assert new_auction_state.automatic_renewal == true
		assert length(new_auction_state.bids) == 3
		assert new_auction_state.end_date_time > auction_state.end_date_time
		assert hd(new_auction_state.bids).bidder_id == buyer_a
		assert new_auction_state.current_price == 2.00
		assert new_auction_state.current_price == hd(new_auction_state.bids).value
	end

	test "It should succeed when selling an auction (without reserve price/without time extension) to the highest bidder", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												time_extension: false}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		buyer_a = context[:buyer_id]
		buyer_b = context[:buyer_id]+1

		bids = [%PlaceBid{auction_id: auction_state.auction_id, 
															bidder_id: buyer_a, 
															requested_qty: 1, 
															max_value: 4.00, 
															created_at: now()},
						%PlaceBid{auction_id: auction_state.auction_id, 
															bidder_id: buyer_b, 
															requested_qty: 1, 
															max_value: 2.00,
															created_at: now()}
					]

		for bid_command <- bids do
			assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])
		end

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == true
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 0
		assert new_auction_state.automatic_renewal == true
		assert length(new_auction_state.bids) == 3
		assert new_auction_state.end_date_time == auction_state.end_date_time
		assert hd(new_auction_state.bids).bidder_id == buyer_a
		assert new_auction_state.current_price == 2.00
		assert new_auction_state.current_price == hd(new_auction_state.bids).value		
	end

	test "It should succeed and the auction (with reserve price/automatic renewal on) shouldn't be sold and should be duplicated when the unique bidder doesn't reach the reserve price", context do
		now = now()

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: now, 
																												end_date_time: now+2,
																												reserve_price: 4.00}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		bid_command = %PlaceBid{auction_id: auction_state.auction_id, 
														bidder_id: context[:buyer_id], 
														requested_qty: 1, 
														max_value: 1.00, 
														created_at: now()}

		assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == false
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 1
		assert new_auction_state.automatic_renewal == true
		assert length(new_auction_state.bids) == 1
		assert new_auction_state.duplicated_to_auction_id != nil

		# Read the auction state
		{:ok, duplicated_auction_state} = AuctionSupervisor.get_auction(new_auction_state.duplicated_to_auction_id, context[:mode])

		assert Auction.is_closed?(duplicated_auction_state.closed_by) == false
		assert duplicated_auction_state.is_sold == false
		assert duplicated_auction_state.duplicated_from_auction_id == auction_state.auction_id
		assert duplicated_auction_state.renewal_count == 1
		assert duplicated_auction_state.original_stock == 1
		assert duplicated_auction_state.stock == 1
		assert duplicated_auction_state.automatic_renewal == true
		assert length(duplicated_auction_state.bids) == 0
		assert duplicated_auction_state.duplicated_to_auction_id == nil
	end

	test "It should succeed and the auction (with reserve price/automatic renewal off) shouldn't be sold and shouldn't be duplicated when the unique bidder doesn't reach the reserve price", context do
		now = now()

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: now, 
																												end_date_time: now+2,
																												automatic_renewal: false,
																												reserve_price: 4.00}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		bid_command = %PlaceBid{auction_id: auction_state.auction_id, 
														bidder_id: context[:buyer_id], 
														requested_qty: 1, 
														max_value: 1.00, 
														created_at: now()}

		assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == false
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 1
		assert new_auction_state.automatic_renewal == false
		assert length(new_auction_state.bids) == 1
		assert new_auction_state.duplicated_to_auction_id == nil
		assert new_auction_state.duplicated_from_auction_id == nil
	end

	test "It should succeed and the auction (with reserve price) should be sold at the reserve price when the unique bid >= reserve price", context do
		now = now()

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: now, 
																												end_date_time: now+2,
																												reserve_price: 4.00}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		bid_command = %PlaceBid{auction_id: auction_state.auction_id, 
														bidder_id: context[:buyer_id], 
														requested_qty: 1, 
														max_value: 5.00, 
														created_at: now()}

		assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == true
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 0
		assert new_auction_state.automatic_renewal == true
		assert length(new_auction_state.bids) == 1
		assert new_auction_state.duplicated_to_auction_id == nil
		assert new_auction_state.duplicated_from_auction_id == nil
		assert new_auction_state.current_price == auction_state.reserve_price
	end

	test "It should succeed and the auction (with reserve price/automatic renewal on) shouldn't be sold and should be duplicated when the highest bid doesn't reach the reserve price", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												reserve_price: 8.00}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		buyer_a = context[:buyer_id]
		buyer_b = context[:buyer_id]+1

		bids = [%PlaceBid{auction_id: auction_state.auction_id, 
											bidder_id: buyer_a, 
											requested_qty: 1, 
											max_value: 4.00, 
											created_at: now()},
						%PlaceBid{auction_id: auction_state.auction_id, 
											bidder_id: buyer_b, 
											requested_qty: 1, 
											max_value: 2.00,
											created_at: now()}
					]

		for bid_command <- bids do
			assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])
		end

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == false
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 1
		assert new_auction_state.automatic_renewal == true
		assert length(new_auction_state.bids) == 3
		assert new_auction_state.duplicated_to_auction_id != nil

		# Read the auction state
		{:ok, duplicated_auction_state} = AuctionSupervisor.get_auction(new_auction_state.duplicated_to_auction_id, context[:mode])

		assert Auction.is_closed?(duplicated_auction_state.closed_by) == false
		assert duplicated_auction_state.is_sold == false
		assert duplicated_auction_state.renewal_count == 1
		assert duplicated_auction_state.original_stock == 1
		assert duplicated_auction_state.stock == 1
		assert duplicated_auction_state.automatic_renewal == true
		assert length(duplicated_auction_state.bids) == 0
		assert duplicated_auction_state.duplicated_to_auction_id == nil
		assert duplicated_auction_state.duplicated_from_auction_id == auction_state.auction_id
	end

	test "It should succeed and the auction (with reserve price/automatic renewal off) shouldn't be sold and shouldn't be duplicated when the highest bid doesn't reach the reserve price", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												automatic_renewal: false,
																												reserve_price: 8.00}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		buyer_a = context[:buyer_id]
		buyer_b = context[:buyer_id]+1

		bids = [%PlaceBid{auction_id: auction_state.auction_id, 
											bidder_id: buyer_a, 
											requested_qty: 1, 
											max_value: 4.00, 
											created_at: now()},
						%PlaceBid{auction_id: auction_state.auction_id, 
											bidder_id: buyer_b, 
											requested_qty: 1, 
											max_value: 2.00,
											created_at: now()}
					]

		for bid_command <- bids do
			assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])
		end

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == false
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 1
		assert new_auction_state.automatic_renewal == false
		assert length(new_auction_state.bids) == 3
		assert new_auction_state.duplicated_to_auction_id == nil
		assert new_auction_state.duplicated_from_auction_id == nil
	end

	test "It should succeed and the auction (with reserve price/automatic renewal on) should be sold to the highest bidder when the highest bid is >= reserve price", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												reserve_price: 8.00}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		buyer_a = context[:buyer_id]
		buyer_b = context[:buyer_id]+1

		bids = [%PlaceBid{auction_id: auction_state.auction_id, 
											bidder_id: buyer_a, 
											requested_qty: 1, 
											max_value: 9.00, 
											created_at: now()},
						%PlaceBid{auction_id: auction_state.auction_id, 
											bidder_id: buyer_b, 
											requested_qty: 1, 
											max_value: 8.20,
											created_at: now()}
					]

		for bid_command <- bids do
			assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])
		end

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == true
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 0
		assert new_auction_state.automatic_renewal == true
		assert length(new_auction_state.bids) == 3
		assert new_auction_state.duplicated_to_auction_id == nil
		assert new_auction_state.duplicated_from_auction_id == nil
		assert new_auction_state.current_price == hd(new_auction_state.bids).value
	end

	test "It should succeed and the auction (without reserve price) should be sold to the unique bidder for a qty of 1 and duplicated with a stock of 3", context do
		now = now()

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | stock: 4,
																												start_date_time: now,
																												end_date_time: now+2}
		
		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		bid_command = %PlaceBid{auction_id: auction_state.auction_id, 
														bidder_id: context[:buyer_id], 
														requested_qty: 1,
														max_value: 1.00, 
														created_at: now()}

		assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == true
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 0
		assert new_auction_state.automatic_renewal == true
		assert length(new_auction_state.bids) == 1
		assert new_auction_state.duplicated_to_auction_id != nil

		# Read the auction state
		{:ok, duplicated_auction_state} = AuctionSupervisor.get_auction(new_auction_state.duplicated_to_auction_id, context[:mode])

		assert Auction.is_closed?(duplicated_auction_state.closed_by) == false
		assert duplicated_auction_state.is_sold == false
		assert duplicated_auction_state.renewal_count == 0
		assert duplicated_auction_state.original_stock == 3
		assert duplicated_auction_state.stock == 3
		assert duplicated_auction_state.automatic_renewal == true
		assert length(duplicated_auction_state.bids) == 0
		assert duplicated_auction_state.duplicated_to_auction_id == nil
		assert duplicated_auction_state.duplicated_from_auction_id == auction_state.auction_id
	end

	test "It should succeed and the auction (without reserve price/with time extension) should be sold to the highest bidder for a qty of 1 and duplicated with a stock of 3", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | stock: 4,
																												start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												time_extension: true}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		buyer_a = context[:buyer_id]
		buyer_b = context[:buyer_id]+1

		bids = [%PlaceBid{auction_id: auction_state.auction_id, 
											bidder_id: buyer_a, 
											requested_qty: 1, 
											max_value: 4.00, 
											created_at: now()},
						%PlaceBid{auction_id: auction_state.auction_id, 
											bidder_id: buyer_b, 
											requested_qty: 1, 
											max_value: 2.00,
											created_at: now()}
					]

		for bid_command <- bids do
			assert {:ack, :bid_placed_time_extended} = AuctionSupervisor.place_bid(bid_command, context[:mode])
		end

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == true
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 0
		assert new_auction_state.automatic_renewal == true
		assert length(new_auction_state.bids) == 3
		assert new_auction_state.duplicated_to_auction_id != nil

		# Read the auction state
		{:ok, duplicated_auction_state} = AuctionSupervisor.get_auction(new_auction_state.duplicated_to_auction_id, context[:mode])

		assert Auction.is_closed?(duplicated_auction_state.closed_by) == false
		assert duplicated_auction_state.is_sold == false
		assert duplicated_auction_state.renewal_count == 0
		assert duplicated_auction_state.original_stock == 3
		assert duplicated_auction_state.stock == 3
		assert duplicated_auction_state.automatic_renewal == true
		assert length(duplicated_auction_state.bids) == 0
		assert duplicated_auction_state.duplicated_to_auction_id == nil
		assert duplicated_auction_state.duplicated_from_auction_id == auction_state.auction_id
		assert duplicated_auction_state.end_date_time > auction_state.end_date_time
	end

	#
	#
	#
	test "It should succeed and the auction (without reserve price/without time extension) should be sold to the highest bidder for a qty of 1 and duplicated with a stock of 3", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+3

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | stock: 4,
																												start_date_time: start_date_time, 
																												end_date_time: end_date_time}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		buyer_a = context[:buyer_id]
		buyer_b = context[:buyer_id]+1

		bids = [%PlaceBid{auction_id: auction_state.auction_id, 
											bidder_id: buyer_a, 
											requested_qty: 1, 
											max_value: 4.00, 
											created_at: now()},
						%PlaceBid{auction_id: auction_state.auction_id, 
											bidder_id: buyer_b, 
											requested_qty: 1, 
											max_value: 2.00,
											created_at: now()}
					]

		for bid_command <- bids do
			assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])
		end

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == true
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 0
		assert new_auction_state.automatic_renewal == true
		assert length(new_auction_state.bids) == 3
		assert new_auction_state.duplicated_to_auction_id != nil
		# No time extension for the original auction
		assert new_auction_state.end_date_time == auction_state.end_date_time

		# Read the auction state
		{:ok, duplicated_auction_state} = AuctionSupervisor.get_auction(new_auction_state.duplicated_to_auction_id, context[:mode])

		assert Auction.is_closed?(duplicated_auction_state.closed_by) == false
		assert duplicated_auction_state.is_sold == false
		assert duplicated_auction_state.renewal_count == 0
		assert duplicated_auction_state.original_stock == 3
		assert duplicated_auction_state.stock == 3
		assert duplicated_auction_state.automatic_renewal == true
		assert length(duplicated_auction_state.bids) == 0
		assert duplicated_auction_state.duplicated_to_auction_id == nil
		assert duplicated_auction_state.duplicated_from_auction_id == auction_state.auction_id
		assert duplicated_auction_state.start_date_time >= auction_state.end_date_time
		assert duplicated_auction_state.end_date_time > duplicated_auction_state.start_date_time
		assert duplicated_auction_state.created_at >= auction_state.end_date_time
	end

	test "It should fail when placing a bid on a closed auction without bids (rejected bid)", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | stock: 1,
																												start_date_time: start_date_time, 
																												end_date_time: end_date_time,
																												automatic_renewal: false}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		bid_command = %PlaceBid{auction_id: auction_state.auction_id, 
														bidder_id: context[:buyer_id], 
														requested_qty: 1,
														max_value: 1.00, 
														created_at: now()}

		assert {:nack, :auction_has_ended} = AuctionSupervisor.place_bid(bid_command, context[:mode])
	end

	#
	#
	#
	test "It should fail when placing a bid on a closed auction with bids (rejected bid)", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | stock: 1,
																												start_date_time: start_date_time, 
																												end_date_time: end_date_time,
																												automatic_renewal: false}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		bid_command = %PlaceBid{auction_id: auction_state.auction_id, 
														bidder_id: context[:buyer_id], 
														requested_qty: 1,
														max_value: 1.00, 
														created_at: now()}

		assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		bid_command = %PlaceBid{auction_id: auction_state.auction_id, 
														bidder_id: context[:buyer_id], 
														requested_qty: 1,
														max_value: 1.00, 
														created_at: now()}

		assert {:nack, :auction_has_ended} = AuctionSupervisor.place_bid(bid_command, context[:mode])
	end

	#
	#
	#
	test "It should fail when placing a bid on a closed auction (fixed price) with bids (rejected bid)", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | stock: 1,
																												sale_type_id: 2,
																												start_date_time: start_date_time, 
																												end_date_time: end_date_time,
																												automatic_renewal: false}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		bid_command = %PlaceBid{auction_id: auction_state.auction_id, 
														bidder_id: context[:buyer_id], 
														requested_qty: 1,
														max_value: 1.00, 
														created_at: now()}

		assert {:ack, :bid_placed_auction_will_close} = AuctionSupervisor.place_bid(bid_command, context[:mode])

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		bid_command = %PlaceBid{auction_id: auction_state.auction_id, 
														bidder_id: context[:buyer_id], 
														requested_qty: 1,
														max_value: 1.00, 
														created_at: now()}

		assert {:nack, :auction_has_ended} = AuctionSupervisor.place_bid(bid_command, context[:mode])
	end

	test "It should succeed and the auction (with reserve price, automatic renewal on, stock = 4) shouldn't be sold and should be duplicated when the bid < reserve price", context do
		now = now()

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: now, 
																												end_date_time: now+2,
																												stock: 4,
																												reserve_price: 4.00}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		bid_command = %PlaceBid{auction_id: auction_state.auction_id, 
														bidder_id: context[:buyer_id], 
														requested_qty: 1, 
														max_value: 1.00, 
														created_at: now()}

		assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == false
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 4
		assert new_auction_state.stock == 4
		assert new_auction_state.automatic_renewal == true
		assert length(new_auction_state.bids) == 1
		assert new_auction_state.duplicated_to_auction_id != nil

		# Read the auction state
		{:ok, duplicated_auction_state} = AuctionSupervisor.get_auction(new_auction_state.duplicated_to_auction_id, context[:mode])

		assert Auction.is_closed?(duplicated_auction_state.closed_by) == false
		assert duplicated_auction_state.is_sold == false
		assert duplicated_auction_state.renewal_count == 1
		assert duplicated_auction_state.original_stock == 4
		assert duplicated_auction_state.stock == 4
		assert duplicated_auction_state.automatic_renewal == true
		assert length(duplicated_auction_state.bids) == 0
		assert duplicated_auction_state.duplicated_to_auction_id == nil
		assert duplicated_auction_state.duplicated_from_auction_id == auction_state.auction_id
	end

	test "It should succeed and the auction (with reserve price, automatic renewal off, stock = 4) shouldn't be sold and should be duplicated when the bid < reserve price", context do
		now = now()

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: now, 
																												end_date_time: now+2,
																												automatic_renewal: false,
																												stock: 4,
																												reserve_price: 4.00}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		bid_command = %PlaceBid{auction_id: auction_state.auction_id, 
														bidder_id: context[:buyer_id], 
														requested_qty: 1, 
														max_value: 1.00, 
														created_at: now()}

		assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == false
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 4
		assert new_auction_state.stock == 4
		assert new_auction_state.automatic_renewal == false
		assert length(new_auction_state.bids) == 1
		assert new_auction_state.duplicated_to_auction_id == nil
		assert new_auction_state.duplicated_from_auction_id == nil
	end

	test "It should succeed and the auction (with reserve price, automatic renewal on, stock = 4) should be sold to the unique bidder at the reserve price and should be duplicated", context do
		now = now()

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: now, 
																												end_date_time: now+2,
																												automatic_renewal: true,
																												stock: 4,
																												reserve_price: 4.00}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		bid_command = %PlaceBid{auction_id: auction_state.auction_id, 
														bidder_id: context[:buyer_id], 
														requested_qty: 1, 
														max_value: 5.00, 
														created_at: now()}

		assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == true
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 0
		assert new_auction_state.automatic_renewal == true
		assert length(new_auction_state.bids) == 1
		assert new_auction_state.duplicated_to_auction_id != nil
		assert new_auction_state.current_price == auction_state.reserve_price

		# Read the auction state
		{:ok, duplicated_auction_state} = AuctionSupervisor.get_auction(new_auction_state.duplicated_to_auction_id, context[:mode])

		assert Auction.is_closed?(duplicated_auction_state.closed_by) == false
		assert duplicated_auction_state.is_sold == false
		assert duplicated_auction_state.duplicated_from_auction_id == auction_state.auction_id
		assert duplicated_auction_state.renewal_count == 0
		assert duplicated_auction_state.original_stock == 3
		assert duplicated_auction_state.stock == 3
		assert duplicated_auction_state.automatic_renewal == true
		assert length(duplicated_auction_state.bids) == 0
		assert duplicated_auction_state.duplicated_to_auction_id == nil
		assert duplicated_auction_state.duplicated_from_auction_id == auction_state.auction_id
	end

	test "It should succeed and the auction (with reserve price, automatic renewal off, stock = 4) should be sold to the unique bidder at the reserve price and should be duplicated", context do
		now = now()

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: now, 
																												end_date_time: now+2,
																												automatic_renewal: false,
																												stock: 4,
																												reserve_price: 4.00}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		bid_command = %PlaceBid{auction_id: auction_state.auction_id, 
														bidder_id: context[:buyer_id], 
														requested_qty: 1, 
														max_value: 5.00, 
														created_at: now()}

		assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == true
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 0
		assert new_auction_state.automatic_renewal == false
		assert length(new_auction_state.bids) == 1
		assert new_auction_state.duplicated_to_auction_id != nil
		assert new_auction_state.current_price == auction_state.reserve_price

		# Read the auction state
		{:ok, duplicated_auction_state} = AuctionSupervisor.get_auction(new_auction_state.duplicated_to_auction_id, context[:mode])

		assert Auction.is_closed?(duplicated_auction_state.closed_by) == false
		assert duplicated_auction_state.is_sold == false
		assert duplicated_auction_state.duplicated_from_auction_id == auction_state.auction_id
		assert duplicated_auction_state.renewal_count == 0
		assert duplicated_auction_state.original_stock == 3
		assert duplicated_auction_state.stock == 3
		assert duplicated_auction_state.automatic_renewal == false
		assert length(duplicated_auction_state.bids) == 0
		assert duplicated_auction_state.duplicated_to_auction_id == nil
		assert duplicated_auction_state.duplicated_from_auction_id == auction_state.auction_id
	end

	test "It should succeed and the auction (with reserve price, automatic renewal on, stock = 4) shouldn't be sold and should be duplicated when the highest bid < reserve price", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												reserve_price: 8.00,
																												stock: 4}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		buyer_a = context[:buyer_id]
		buyer_b = context[:buyer_id]+1

		bids = [%PlaceBid{auction_id: auction_state.auction_id, 
											bidder_id: buyer_a, 
											requested_qty: 1, 
											max_value: 4.00, 
											created_at: now()},
						%PlaceBid{auction_id: auction_state.auction_id, 
											bidder_id: buyer_b, 
											requested_qty: 1, 
											max_value: 2.00,
											created_at: now()}
					]

		for bid_command <- bids do
			assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])
		end

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == false
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 4
		assert new_auction_state.stock == 4
		assert new_auction_state.automatic_renewal == true
		assert length(new_auction_state.bids) == 3
		assert new_auction_state.duplicated_to_auction_id != nil

		# Read the auction state
		{:ok, duplicated_auction_state} = AuctionSupervisor.get_auction(new_auction_state.duplicated_to_auction_id, context[:mode])

		assert Auction.is_closed?(duplicated_auction_state.closed_by) == false
		assert duplicated_auction_state.is_sold == false
		assert duplicated_auction_state.renewal_count == 1
		assert duplicated_auction_state.original_stock == 4
		assert duplicated_auction_state.stock == 4
		assert duplicated_auction_state.automatic_renewal == true
		assert length(duplicated_auction_state.bids) == 0
		assert duplicated_auction_state.duplicated_to_auction_id == nil
		assert duplicated_auction_state.duplicated_from_auction_id == auction_state.auction_id
	end

	test "It should succeed and the auction (with reserve price, automatic renewal off, stock = 4) shouldn't be sold and shouldn't be duplicated when the highest bid < reserve price", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												automatic_renewal: false,
																												stock: 4,
																												reserve_price: 8.00}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		buyer_a = context[:buyer_id]
		buyer_b = context[:buyer_id]+1

		bids = [%PlaceBid{auction_id: auction_state.auction_id, 
											bidder_id: buyer_a, 
											requested_qty: 1, 
											max_value: 4.00, 
											created_at: now()},
						%PlaceBid{auction_id: auction_state.auction_id, 
											bidder_id: buyer_b, 
											requested_qty: 1, 
											max_value: 2.00,
											created_at: now()}
					]

		for bid_command <- bids do
			assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])
		end

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == false
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 4
		assert new_auction_state.stock == 4
		assert new_auction_state.automatic_renewal == false
		assert length(new_auction_state.bids) == 3
		assert new_auction_state.duplicated_to_auction_id == nil
		assert new_auction_state.duplicated_from_auction_id == nil
	end

	test "It should succeed and the auction (with reserve price, automatic renewal off, stock = 4) should be sold and should be duplicated when the highest bid >= reserve price", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												reserve_price: 8.00,
																												stock: 4}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		buyer_a = context[:buyer_id]
		buyer_b = context[:buyer_id]+1

		bids = [%PlaceBid{auction_id: auction_state.auction_id, 
											bidder_id: buyer_a, 
											requested_qty: 1, 
											max_value: 9.00, 
											created_at: now()},
						%PlaceBid{auction_id: auction_state.auction_id, 
											bidder_id: buyer_b, 
											requested_qty: 1, 
											max_value: 8.20,
											created_at: now()}
					]

		for bid_command <- bids do
			assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])
		end

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == true
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 0
		assert new_auction_state.automatic_renewal == true
		assert length(new_auction_state.bids) == 3
		assert new_auction_state.duplicated_to_auction_id != nil
		assert new_auction_state.current_price == hd(new_auction_state.bids).value

		# Read the auction state
		{:ok, duplicated_auction_state} = AuctionSupervisor.get_auction(new_auction_state.duplicated_to_auction_id, context[:mode])

		assert Auction.is_closed?(duplicated_auction_state.closed_by) == false
		assert duplicated_auction_state.is_sold == false
		assert duplicated_auction_state.duplicated_from_auction_id == auction_state.auction_id
		assert duplicated_auction_state.renewal_count == 0
		assert duplicated_auction_state.original_stock == 3
		assert duplicated_auction_state.stock == 3
		assert duplicated_auction_state.automatic_renewal == true
		assert length(duplicated_auction_state.bids) == 0
		assert duplicated_auction_state.duplicated_to_auction_id == nil
		assert duplicated_auction_state.duplicated_from_auction_id == auction_state.auction_id
	end

	test "It should succeed and the auction (with reserve price, automatic renewal off) should be sold and should be duplicated when the highest bid >= reserve price", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												reserve_price: 8.00,
																												automatic_renewal: false,
																												stock: 4}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		buyer_a = context[:buyer_id]
		buyer_b = context[:buyer_id]+1

		bids = [%PlaceBid{auction_id: auction_state.auction_id, 
											bidder_id: buyer_a, 
											requested_qty: 1, 
											max_value: 9.00, 
											created_at: now()},
						%PlaceBid{auction_id: auction_state.auction_id, 
											bidder_id: buyer_b, 
											requested_qty: 1, 
											max_value: 8.20,
											created_at: now()}
					]

		for bid_command <- bids do
			assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])
		end

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == true
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 0
		assert new_auction_state.automatic_renewal == false
		assert length(new_auction_state.bids) == 3
		assert new_auction_state.duplicated_to_auction_id != nil
		assert new_auction_state.current_price == hd(new_auction_state.bids).value

		# Read the auction state
		{:ok, duplicated_auction_state} = AuctionSupervisor.get_auction(new_auction_state.duplicated_to_auction_id, context[:mode])

		assert Auction.is_closed?(duplicated_auction_state.closed_by) == false
		assert duplicated_auction_state.is_sold == false
		assert duplicated_auction_state.duplicated_from_auction_id == auction_state.auction_id
		assert duplicated_auction_state.renewal_count == 0
		assert duplicated_auction_state.original_stock == 3
		assert duplicated_auction_state.stock == 3
		assert duplicated_auction_state.automatic_renewal == false
		assert length(duplicated_auction_state.bids) == 0
		assert duplicated_auction_state.duplicated_to_auction_id == nil
		assert duplicated_auction_state.duplicated_from_auction_id == auction_state.auction_id
	end

	test "It should succeed when checking different cases of bid rejection on a variable price auction without bids", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+1

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												automatic_renewal: false,
																												stock: 1}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, _new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		bid_command = %PlaceBid{auction_id: auction_state.auction_id, 
														bidder_id: context[:buyer_id], 
														requested_qty: 1, 
														max_value: 5.00, 
														created_at: now()}

		# 5-1  the auction has a closed status
		updated_auction_state = %AuctionData{auction_state | closed_by: context[:seller_id]}
		assert {:nack, :auction_has_ended, _closed_auction_state} = Auction.process_command(bid_command, context[:mode], updated_auction_state)

		# 5-2  the auction is suspended
		updated_auction_state = %AuctionData{auction_state | closed_by: nil, is_suspended: true}
		assert {:nack, :auction_is_suspended, _closed_auction_state} = Auction.process_command(bid_command, context[:mode], updated_auction_state)

		# 5-3  the bidder is the auction's creator
		updated_auction_state = %AuctionData{auction_state | closed_by: nil}
		updated_bid_command = %PlaceBid{bid_command | bidder_id: auction_state.seller_id}
		assert {:nack, :self_bidding, _closed_auction_state} = Auction.process_command(updated_bid_command, context[:mode], updated_auction_state)

		# 5-4  the auction's owner account is locked
		# TODO

		# 5-5  the auction's end time has been reached
		updated_auction_state = %AuctionData{auction_state | closed_by: nil}
		updated_bid_command = %PlaceBid{bid_command | created_at: end_date_time+1}
		assert {:nack, :auction_has_ended, _closed_auction_state} = Auction.process_command(updated_bid_command, context[:mode], updated_auction_state)

		# 5-6  the auction is not already started
		updated_auction_state = %AuctionData{auction_state | closed_by: nil}
		updated_bid_command = %PlaceBid{bid_command | created_at: start_date_time-1}
		assert {:nack, :auction_not_yet_started, _closed_auction_state} = Auction.process_command(updated_bid_command, context[:mode], updated_auction_state)

		# 5-7  the requested bid qty is <> 1
		updated_auction_state = %AuctionData{auction_state | closed_by: nil, end_date_time: now+10}
		updated_bid_command = %PlaceBid{bid_command | requested_qty: 120}
		assert {:nack, :wrong_requested_qty, _closed_auction_state} = Auction.process_command(updated_bid_command, context[:mode], updated_auction_state)

		# 5-8  the auction's remaining stock is < 1
		updated_auction_state = %AuctionData{auction_state | closed_by: nil, end_date_time: now+10, stock: 0}
		updated_bid_command = bid_command
		assert {:nack, :not_enough_stock, _closed_auction_state} = Auction.process_command(updated_bid_command, context[:mode], updated_auction_state)

		# 5-9  the bid's (max) value is <  than the auction's current price (when the auction has no bid)
		updated_auction_state = %AuctionData{auction_state | closed_by: nil, end_date_time: now+10}
		updated_bid_command = %PlaceBid{bid_command | max_value: auction_state.current_price-0.10}
		assert {:nack, :bid_below_allowed_min, _} = Auction.process_command(updated_bid_command, context[:mode], updated_auction_state)
	end

	test "It should succeed when checking different cases of bid rejection on a variable price auction with bids", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												automatic_renewal: false,
																												stock: 1}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		bid_command = %PlaceBid{auction_id: auction_state.auction_id, 
														bidder_id: context[:buyer_id], 
														requested_qty: 1, 
														max_value: 5.00, 
														created_at: now()}
		assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# 6-1  the auction has a closed status
		updated_auction_state = %AuctionData{auction_state | closed_by: context[:seller_id]}
		assert {:nack, :auction_has_ended, _closed_auction_state} = Auction.process_command(bid_command, context[:mode], updated_auction_state)

		# 6-2  the auction is suspended
		updated_auction_state = %AuctionData{auction_state | closed_by: nil, is_suspended: true}
		assert {:nack, :auction_is_suspended, _closed_auction_state} = Auction.process_command(bid_command, context[:mode], updated_auction_state)

		# 6-3  the bidder is the auction's creator
		updated_auction_state = %AuctionData{auction_state | closed_by: nil}
		updated_bid_command = %PlaceBid{bid_command | bidder_id: auction_state.seller_id}
		assert {:nack, :self_bidding, _closed_auction_state} = Auction.process_command(updated_bid_command, context[:mode], updated_auction_state)

		# 6-4  the auction's owner account is locked
		# TODO

		# 6-5  the auction's end time has been reached
		updated_auction_state = %AuctionData{auction_state | closed_by: nil}
		updated_bid_command = %PlaceBid{bid_command | created_at: end_date_time+1}
		assert {:nack, :auction_has_ended, _closed_auction_state} = Auction.process_command(updated_bid_command, context[:mode], updated_auction_state)

		# 6-6  the auction is not already started
		updated_auction_state = %AuctionData{auction_state | closed_by: nil}
		updated_bid_command = %PlaceBid{bid_command | created_at: start_date_time-1}
		assert {:nack, :auction_not_yet_started, _closed_auction_state} = Auction.process_command(updated_bid_command, context[:mode], updated_auction_state)

		# 6-7  the requested bid qty is <> 1
		updated_auction_state = %AuctionData{auction_state | closed_by: nil, end_date_time: now+10}
		updated_bid_command = %PlaceBid{bid_command | requested_qty: 120}
		assert {:nack, :wrong_requested_qty, _closed_auction_state} = Auction.process_command(updated_bid_command, context[:mode], updated_auction_state)

		# 6-8  the auction's remaining stock is < 1
		updated_auction_state = %AuctionData{auction_state | closed_by: nil, end_date_time: now+10, stock: 0}
		updated_bid_command = bid_command
		assert {:nack, :not_enough_stock, _closed_auction_state} = Auction.process_command(updated_bid_command, context[:mode], updated_auction_state)

		# 6-9  the bid's (max) value is <  than the auction's current price (when the auction has at least one bid)
		updated_auction_state = %AuctionData{auction_state | closed_by: nil, end_date_time: now+10, stock: 1}
		updated_bid_command = %PlaceBid{bid_command | max_value: auction_state.current_price}
		assert {:nack, :bid_below_allowed_min, _closed_auction_state} = Auction.process_command(updated_bid_command, context[:mode], updated_auction_state)
	end

	test "It should succeed when the highest bidder raises its maximum bid", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | stock: 1,
																												start_date_time: start_date_time, 
																												end_date_time: end_date_time,
																												automatic_renewal: false}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		bid_command = %PlaceBid{auction_id: auction_state.auction_id, 
														bidder_id: context[:buyer_id], 
														requested_qty: 1,
														max_value: 1.00, 
														created_at: now()}

		assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])

		bid_command = %PlaceBid{auction_id: auction_state.auction_id, 
														bidder_id: context[:buyer_id], 
														requested_qty: 1,
														max_value: 2.00, 
														created_at: now()}

		assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		assert length(new_auction_state.bids) == 2
	end

	test "It should succeed when checking different cases of bid rejection on a fixed price auction", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												automatic_renewal: false,
																												sale_type_id: 2,
																												stock: 15}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		bid_command = %PlaceBid{auction_id: auction_state.auction_id, 
														bidder_id: context[:buyer_id], 
														requested_qty: 1, 
														max_value: auction_state.start_price, 
														created_at: now()}
		assert {:ack, :bid_placed_and_duplicated_auction, _duplicated_auction_state} = AuctionSupervisor.place_bid(bid_command, context[:mode])

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# 8-1  the auction has a closed status
		updated_auction_state = %AuctionData{auction_state | closed_by: context[:seller_id]}
		assert {:nack, :auction_has_ended, _closed_auction_state} = Auction.process_command(bid_command, context[:mode], updated_auction_state)

		# 8-2  the auction is suspended
		updated_auction_state = %AuctionData{auction_state | closed_by: nil, is_suspended: true}
		assert {:nack, :auction_is_suspended, _closed_auction_state} = Auction.process_command(bid_command, context[:mode], updated_auction_state)

		# 8-3  the bidder is the auction's creator
		updated_auction_state = %AuctionData{auction_state | closed_by: nil}
		updated_bid_command = %PlaceBid{bid_command | bidder_id: auction_state.seller_id}
		assert {:nack, :self_bidding, _closed_auction_state} = Auction.process_command(updated_bid_command, context[:mode], updated_auction_state)

		# 8-4  the auction's owner account is locked
		# TODO

		# 8-5  the auction's end time has been reached
		updated_auction_state = %AuctionData{auction_state | closed_by: nil}
		updated_bid_command = %PlaceBid{bid_command | created_at: end_date_time+1}
		assert {:nack, :auction_has_ended, _closed_auction_state} = Auction.process_command(updated_bid_command, context[:mode], updated_auction_state)

		# 8-6  the auction is not already started
		updated_auction_state = %AuctionData{auction_state | closed_by: nil}
		updated_bid_command = %PlaceBid{bid_command | created_at: start_date_time-1}
		assert {:nack, :auction_not_yet_started, _closed_auction_state} = Auction.process_command(updated_bid_command, context[:mode], updated_auction_state)

		# 8-7  the requested bid qty is greater than the auction's stock
		updated_auction_state = %AuctionData{auction_state | closed_by: nil, end_date_time: now+10}
		updated_bid_command = %PlaceBid{bid_command | requested_qty: 120}
		assert {:nack, :not_enough_stock, _closed_auction_state} = Auction.process_command(updated_bid_command, context[:mode], updated_auction_state)

		# 8-8  the requested bid qty is < 1
		updated_auction_state = %AuctionData{auction_state | closed_by: nil, end_date_time: now+10, stock: 120}
		updated_bid_command = %PlaceBid{bid_command | requested_qty: 0}
		assert {:nack, :wrong_requested_qty, _closed_auction_state} = Auction.process_command(updated_bid_command, context[:mode], updated_auction_state)

		# 8-9  the bid's (max) value is <> than the auction's current price
		updated_auction_state = %AuctionData{auction_state | closed_by: nil, end_date_time: now+10, stock: 1}
		updated_bid_command = %PlaceBid{bid_command | max_value: auction_state.current_price+0.10}
		assert {:nack, :wrong_bid_price, _} = Auction.process_command(updated_bid_command, context[:mode], updated_auction_state)
	end

	test "It should succeed when selling an auction having multiple bidders (without reserve price, automatic renewal off, stock = 1)", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												automatic_renewal: false,
																												stock: 1}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		buyer_a = context[:buyer_id]
		buyer_b = context[:buyer_id]+1
		buyer_c = context[:buyer_id]+2

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
		#		

		bids = [{buyer_a, 2.00}, {buyer_b, 1.30},	{buyer_a, 3.00}, {buyer_c, 2.5}, {buyer_b, 3.00}]

		for {bidder_id, max_value} <- bids do
			bid_command = %PlaceBid{auction_id: auction_state.auction_id,
															bidder_id: bidder_id,
															requested_qty: 1,
															max_value: max_value,
															created_at: now()}
			assert {:ack, :bid_placed} = AuctionSupervisor.place_bid(bid_command, context[:mode])
		end

		# The list of bids that is expected when the auction closes
		expected_bids = [
			%{auction_id: auction_state.auction_id, bidder_id: 270, is_auto: true, is_visible: true, max_value: 3.0, requested_qty: 1, value: 3.0},
		 	%{auction_id: auction_state.auction_id, bidder_id: 271, is_auto: false, is_visible: true, max_value: 3.0, requested_qty: 1, value: 3.0},
 			%{auction_id: auction_state.auction_id, bidder_id: 270, is_auto: true, is_visible: true, max_value: 3.0, requested_qty: 1, value: 2.5},
 			%{auction_id: auction_state.auction_id, bidder_id: 272, is_auto: false, is_visible: true, max_value: 2.5, requested_qty: 1, value: 2.5},
 			%{auction_id: auction_state.auction_id, bidder_id: 270, is_auto: false, is_visible: false, max_value: 3.0, requested_qty: 1, value: 1.3},
 			%{auction_id: auction_state.auction_id, bidder_id: 270, is_auto: true, is_visible: true, max_value: 2.0, requested_qty: 1, value: 1.3},
 			%{auction_id: auction_state.auction_id, bidder_id: 271, is_auto: false, is_visible: true, max_value: 1.3, requested_qty: 1, value: 1.3},
 			%{auction_id: auction_state.auction_id, bidder_id: 270, is_auto: false, is_visible: true, max_value: 2.0, requested_qty: 1, value: 1.0}
 		]

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Make a list of bids without the created_at and bidder_name keys
		cleaned_bids = Enum.map(new_auction_state.bids, fn(b) -> Map.delete(b, :created_at) |> Map.delete(:bidder_name) end)

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == true
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 0
		assert new_auction_state.automatic_renewal == false
		assert new_auction_state.duplicated_to_auction_id == nil
		assert new_auction_state.duplicated_from_auction_id == nil
		assert cleaned_bids == expected_bids
	end

	test "It should succeed when selling an auction having multiple bidders and some rejected bids (without reserve price, automatic renewal off, stock = 1)", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												automatic_renewal: false,
																												stock: 1}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		buyer_a = context[:buyer_id]
		buyer_b = context[:buyer_id]+1

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
			{buyer_a, 0.50, {:nack, :bid_below_allowed_min}},
			{buyer_a, 1.00, {:ack, :bid_placed}},
			{buyer_b, 0.50, {:nack, :bid_below_allowed_min}},
			{buyer_b, 1.00, {:nack, :bid_below_allowed_min}}
		]

		for {bidder_id, max_value, status} <- bids do
			bid_command = %PlaceBid{auction_id: auction_state.auction_id,
															bidder_id: bidder_id,
															requested_qty: 1,
															max_value: max_value,
															created_at: now()}
			assert ^status = AuctionSupervisor.place_bid(bid_command, context[:mode])
		end

		# The list of bids that is expected when the auction closes
		expected_bids = [
			%{auction_id: auction_state.auction_id, bidder_id: 270, is_auto: false, is_visible: true, max_value: 1.0, requested_qty: 1, value: 1.0}
 		]

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Make a list of bids without the created_at and bidder_name keys
		cleaned_bids = Enum.map(new_auction_state.bids, fn(b) -> Map.delete(b, :created_at) |> Map.delete(:bidder_name) end)

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == true
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 0
		assert new_auction_state.automatic_renewal == false
		assert new_auction_state.duplicated_to_auction_id == nil
		assert new_auction_state.duplicated_from_auction_id == nil
		assert cleaned_bids == expected_bids
	end

	test "It should succeed when an auction having one bidder and some rejected bids is not sold (with reserve price, automatic renewal off, stock = 1)", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												automatic_renewal: false,
																												reserve_price: 8.00,
																												stock: 1}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		buyer_a = context[:buyer_id]
		buyer_b = context[:buyer_id]+1

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
			{buyer_a, 0.50, {:nack, :bid_below_allowed_min}},
			{buyer_a, 1.00, {:ack, :bid_placed}},
			{buyer_b, 2.00, {:ack, :bid_placed}},
			{buyer_a, 1.10, {:nack, :bid_below_allowed_min}}
		]

		for {bidder_id, max_value, status} <- bids do
			bid_command = %PlaceBid{auction_id: auction_state.auction_id,
															bidder_id: bidder_id,
															requested_qty: 1,
															max_value: max_value,
															created_at: now()}
			assert ^status = AuctionSupervisor.place_bid(bid_command, context[:mode])
		end

		# The list of bids that is expected when the auction closes
		expected_bids = [
			%{auction_id: auction_state.auction_id, bidder_id: buyer_b, is_auto: false, is_visible: true, max_value: 2.0, requested_qty: 1, value: 1.10},
			%{auction_id: auction_state.auction_id, bidder_id: buyer_a, is_auto: false, is_visible: true, max_value: 1.0, requested_qty: 1, value: 1.00}
 		]

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Make a list of bids without the created_at and bidder_name keys
		cleaned_bids = Enum.map(new_auction_state.bids, fn(b) -> Map.delete(b, :created_at) |> Map.delete(:bidder_name) end)

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == false
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 1
		assert new_auction_state.automatic_renewal == false
		assert new_auction_state.duplicated_to_auction_id == nil
		assert new_auction_state.duplicated_from_auction_id == nil
		assert cleaned_bids == expected_bids
	end		

	test "It should succeed when an auction having one bidder and some rejected bids is sold (with reserve price, automatic renewal off, stock = 1)", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												automatic_renewal: false,
																												reserve_price: 8.00,
																												stock: 1}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		buyer_a = context[:buyer_id]

		# Auction -----		Bid ---------------		|		Auction -----		Bid list ----------------------------------
		# current_price 	bidder 		max_value 	|		current_price 	bidder 		value 	max_value		auto 	visible
		# =====================================================================================================
		# 1.00						buyer_a		0.50		R		|		1.00						
		# -----------------------------------------------------------------------------------------------------
		# 1.00						buyer_a		8.00				|		8.00						buyer_a		8.00		8.00				N 		O
		#		

		bids = [
			{buyer_a, 0.50, {:nack, :bid_below_allowed_min}},
			{buyer_a, 8.00, {:ack, :bid_placed}}
		]

		for {bidder_id, max_value, status} <- bids do
			bid_command = %PlaceBid{auction_id: auction_state.auction_id,
															bidder_id: bidder_id,
															requested_qty: 1,
															max_value: max_value,
															created_at: now()}
			assert ^status = AuctionSupervisor.place_bid(bid_command, context[:mode])
		end

		# The list of bids that is expected when the auction closes
		expected_bids = [
			%{auction_id: auction_state.auction_id, bidder_id: 270, is_auto: false, is_visible: true, max_value: 8.0, requested_qty: 1, value: 8.0}
 		]

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Make a list of bids without the created_at and bidder_name keys
		cleaned_bids = Enum.map(new_auction_state.bids, fn(b) -> Map.delete(b, :created_at) |> Map.delete(:bidder_name) end)

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == true
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 0
		assert new_auction_state.automatic_renewal == false
		assert new_auction_state.duplicated_to_auction_id == nil
		assert new_auction_state.duplicated_from_auction_id == nil
		assert cleaned_bids == expected_bids
	end

	test "It should succeed when an auction having one bidder and some rejected bids is sold (with reserve price, automatic renewal off, stock = 1, raises its highest bid)", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												automatic_renewal: false,
																												reserve_price: 8.00,
																												stock: 1}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		buyer_a = context[:buyer_id]

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
			{buyer_a, 0.50, {:nack, :bid_below_allowed_min}},
			{buyer_a, 8.00, {:ack, :bid_placed}},
			{buyer_a, 9.00, {:ack, :bid_placed}}
		]

		for {bidder_id, max_value, status} <- bids do
			bid_command = %PlaceBid{auction_id: auction_state.auction_id,
															bidder_id: bidder_id,
															requested_qty: 1,
															max_value: max_value,
															created_at: now()}
			assert ^status = AuctionSupervisor.place_bid(bid_command, context[:mode])
		end

		# The list of bids that is expected when the auction closes
		expected_bids = [
			%{auction_id: auction_state.auction_id, bidder_id: 270, is_auto: false, is_visible: false, max_value: 9.0, requested_qty: 1, value: 8.0},
			%{auction_id: auction_state.auction_id, bidder_id: 270, is_auto: false, is_visible: true, max_value: 8.0, requested_qty: 1, value: 8.0}
 		]

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Make a list of bids without the created_at and bidder_name keys
		cleaned_bids = Enum.map(new_auction_state.bids, fn(b) -> Map.delete(b, :created_at) |> Map.delete(:bidder_name) end)

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == true
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 0
		assert new_auction_state.automatic_renewal == false
		assert new_auction_state.duplicated_to_auction_id == nil
		assert new_auction_state.duplicated_from_auction_id == nil
		assert cleaned_bids == expected_bids
	end	

	test "It should succeed when an auction having one bidder and one rejected bid is sold (with reserve price, automatic renewal off, stock = 1)", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												automatic_renewal: false,
																												reserve_price: 8.00,
																												stock: 1}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		buyer_a = context[:buyer_id]

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
			{buyer_a, 0.50, {:nack, :bid_below_allowed_min}},
			{buyer_a, 1.00, {:ack, :bid_placed}},
			{buyer_a, 8.00, {:ack, :bid_placed}}
		]

		for {bidder_id, max_value, status} <- bids do
			bid_command = %PlaceBid{auction_id: auction_state.auction_id,
															bidder_id: bidder_id,
															requested_qty: 1,
															max_value: max_value,
															created_at: now()}
			assert ^status = AuctionSupervisor.place_bid(bid_command, context[:mode])
		end

		# The list of bids that is expected when the auction closes
		expected_bids = [
			%{auction_id: auction_state.auction_id, bidder_id: buyer_a, is_auto: false, is_visible: true, max_value: 8.0, requested_qty: 1, value: 8.00},
			%{auction_id: auction_state.auction_id, bidder_id: buyer_a, is_auto: false, is_visible: true, max_value: 1.0, requested_qty: 1, value: 1.00}
 		]

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Make a list of bids without the created_at and bidder_name keys
		cleaned_bids = Enum.map(new_auction_state.bids, fn(b) -> Map.delete(b, :created_at) |> Map.delete(:bidder_name) end)

		assert Auction.is_closed?(new_auction_state.closed_by) == true
		assert new_auction_state.is_sold == true
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 0
		assert new_auction_state.automatic_renewal == false
		assert new_auction_state.duplicated_to_auction_id == nil
		assert new_auction_state.duplicated_from_auction_id == nil
		assert cleaned_bids == expected_bids
	end

	test "It should succeed when an auction having one bidder (raises its highest bid) and one rejected bid is sold (with reserve price, automatic renewal off, stock = 1)", context do
		now = now()
		start_date_time = now
		end_date_time = start_date_time+2

		# Create the auction
		vp_create_command = %{context[:vp_create_command] | start_date_time: start_date_time, 
																												end_date_time: end_date_time, 
																												automatic_renewal: false,
																												reserve_price: 8.00,
																												stock: 1}

		{:ok, _, auction_state} = AuctionSupervisor.create_auction(struct(CreateAuction, vp_create_command), context[:mode])

		buyer_a = context[:buyer_id]

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
			{buyer_a, 0.50, {:nack, :bid_below_allowed_min}},
			{buyer_a, 1.00, {:ack, :bid_placed}},
			{buyer_a, 7.00, {:ack, :bid_placed}},
			{buyer_a, 9.00, {:ack, :bid_placed}},
			{buyer_a, 10.00, {:ack, :bid_placed}}
		]

		for {bidder_id, max_value, status} <- bids do
			bid_command = %PlaceBid{auction_id: auction_state.auction_id,
															bidder_id: bidder_id,
															requested_qty: 1,
															max_value: max_value,
															created_at: now()}
			assert ^status = AuctionSupervisor.place_bid(bid_command, context[:mode])
		end

		# The list of bids that is expected when the auction closes
		expected_bids = [
			%{auction_id: auction_state.auction_id, bidder_id: 270, is_auto: false, is_visible: false, max_value: 10.0, requested_qty: 1, value: 8.0},
      %{auction_id: auction_state.auction_id, bidder_id: 270, is_auto: false, is_visible: true, max_value: 9.0, requested_qty: 1, value: 8.0},
      %{auction_id: auction_state.auction_id, bidder_id: 270, is_auto: false, is_visible: false, max_value: 7.0, requested_qty: 1, value: 1.0},
      %{auction_id: auction_state.auction_id, bidder_id: 270, is_auto: false, is_visible: true, max_value: 1.0, requested_qty: 1, value: 1.0}
 		]

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Wait for the auction to end
		time_to_sleep = (new_auction_state.end_date_time-now()+1)*1000
		:timer.sleep(time_to_sleep)

		# Read the auction state
		{:ok, new_auction_state} = AuctionSupervisor.get_auction(auction_state.auction_id, context[:mode])

		# Make a list of bids without the created_at and bidder_name keys
		cleaned_bids = Enum.map(new_auction_state.bids, fn(b) -> Map.delete(b, :created_at) |> Map.delete(:bidder_name) end)

		assert Auction.is_closed?(new_auction_state.closed_by)
		assert new_auction_state.is_sold == true
		assert new_auction_state.renewal_count == 0
		assert new_auction_state.original_stock == 1
		assert new_auction_state.stock == 0
		assert new_auction_state.automatic_renewal == false
		assert new_auction_state.duplicated_to_auction_id == nil
		assert new_auction_state.duplicated_from_auction_id == nil
		assert cleaned_bids == expected_bids
	end

end
