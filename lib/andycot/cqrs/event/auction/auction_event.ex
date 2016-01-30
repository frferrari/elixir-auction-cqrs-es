defmodule Andycot.Event.Auction do

	defmodule AuctionStarted do 
		defstruct auction_id: nil, 
							duplicated_from_auction_id: nil,
							seller_id: nil,
							type_id: nil,

							title: nil,
							description: nil,

							year: nil,

							area_id: nil,
							topic_ids: [],

							options: [],

							matched_id: nil,

							listed_time_id: nil,
							sale_type_id: nil,

							start_price: nil,
							current_price: nil,
							reserve_price: nil,
							bid_up: nil,
							currency: nil,

							original_stock: nil,
							stock: nil,

							start_date_time: nil,
							end_date_time: nil,
							created_at: nil,

							automatic_renewal: nil,
							time_extension: nil,
							
							renewal_count: nil,
							watch_count: nil,				# this count doesn't exist in the legacy model
							visit_count: nil,				# named "view_count" in the legacy model

							slug: nil,

							pictures: []
	end

	defmodule AuctionScheduled do 
		defstruct auction_id: nil, 
							duplicated_from_auction_id: nil,
							seller_id: nil,
							type_id: nil,

							title: nil,
							description: nil,

							year: nil,

							area_id: nil,
							topic_ids: [],

							options: [],

							matched_id: nil,

							listed_time_id: nil,
							sale_type_id: nil,

							start_price: nil,
							current_price: nil,
							reserve_price: nil,
							bid_up: nil,
							currency: nil,

							original_stock: nil,
							stock: nil,

							start_date_time: nil,
							end_date_time: nil,
							created_at: nil,

							automatic_renewal: nil,
							time_extension: false,

							renewal_count: nil,
							watch_count: nil,				# this count doesn't exist in the legacy model
							visit_count: nil,				# named "view_count" in the legacy model

							slug: nil,

							pictures: []
	end

	defmodule AuctionCreated do 
		defstruct auction_id: nil, 
							duplicated_from_auction_id: nil,
							seller_id: nil,
							type_id: nil,

							title: nil,
							description: nil,

							year: nil,

							area_id: nil,
							topic_ids: [],

							options: [],

							matched_id: nil,

							listed_time_id: nil,
							sale_type_id: nil,

							start_price: nil,
							current_price: nil,
							reserve_price: nil,
							bid_up: nil,
							currency: nil,

							original_stock: nil,
							stock: nil,

							start_date_time: nil,
							end_date_time: nil,
							created_at: nil,

							automatic_renewal: nil,
							time_extension: false,

							renewal_count: nil,
							watch_count: nil,

							slug: nil,

							pictures: []
	end

	defmodule AuctionClosed do
		defstruct auction_id: nil,
							closed_by: nil,
							reason: nil,
							created_at: nil
	end

	defmodule AuctionRenewed do 
		defstruct auction_id: nil,
							start_date_time: nil,
							end_date_time: nil,
							created_at: nil
	end

	defmodule AuctionSuspended do 
		defstruct auction_id: nil,
							suspended_by: nil,
							created_at: nil
	end

	defmodule AuctionResumed do 
		defstruct auction_id: nil,
							resumed_by: nil,
							start_date_time: nil,
							end_date_time: nil,
							created_at: nil
	end

	defmodule AuctionRestarted do
	end

	defmodule AuctionSold do 
		defstruct auction_id: nil,
							sold_to: nil,
							sold_qty: nil,
							price: nil,
							currency: nil,
							created_at: nil
	end

	defmodule BidPlaced do 
		defstruct auction_id: nil,
							bidder_id: nil,
							bidder_name: nil,
							requested_qty: nil,
							max_value: nil,
							created_at: nil
	end

	defmodule BidRejected do
		defstruct auction_id: nil,
							bidder_id: nil,
							bidder_name: nil,
							requested_qty: nil,
							max_value: nil,
							reason: nil,
							created_at: nil
	end

	defmodule CancelRejected do
		defstruct auction_id: nil,
							cancelled_by: nil,
							reason: nil,
							created_at: nil
	end

	defmodule CloseRejected do
		defstruct auction_id: nil,
							closed_by: nil,
							reason: nil,
							created_at: nil
	end

	defmodule SuspendRejected do
		defstruct auction_id: nil,
							suspended_by: nil,
							reason: nil,
							created_at: nil
	end

	defmodule RenewRejected do
		defstruct auction_id: nil,
							renewed_by: nil,
							reason: nil,
							created_at: nil
	end

	defmodule ResumeRejected do
		defstruct auction_id: nil,
							resumed_by: nil,
							reason: nil,
							created_at: nil
	end

	defmodule WatchCountIncremented do
		defstruct auction_id: nil,
							created_at: nil
	end

	defmodule WatchCountDecremented do
		defstruct auction_id: nil,
							created_at: nil
	end

	defmodule VisitCountIncremented do
		defstruct auction_id: nil,
							created_at: nil
	end

end