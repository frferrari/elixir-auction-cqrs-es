defmodule Andycot.Command.Auction do

	#
	# A CreateAuction will be transformed to a StartAuction or a ScheduleAuction
	# depending on the auction's start_date_time
	#
	defmodule CreateAuction do 
		defstruct auction_id: nil, 
							cloned_from_auction_id: nil,
							seller_id: nil,

							type_id: nil,
							listed_time_id: nil,
							sale_type_id: nil,

							title: nil,
							description: nil,

							year: nil,
							area_id: nil,
							topic_ids: [],

							options: [],

							matched_id: nil,

							start_price: nil,
							bid_up: 0.10,
							reserve_price: nil,

							stock: 1,

							start_date_time: nil,
							end_date_time: nil,

							automatic_renewal: true,
							time_extension: false,

							renewal_count: 0,
							watch_count: 0,				# this count doesn't exist in the legacy model
							visit_count: 0,				# named "view_count" in the legacy model
							
							currency: nil,
							slug: nil,

							pictures: [],
							
							created_at: nil
	end

	defmodule StartAuction do 
		defstruct auction_id: nil, 
							cloned_from_auction_id: nil,
							cloned_to_auction_id: nil,
							seller_id: nil,

							type_id: nil,
							listed_time_id: nil,
							sale_type_id: nil,

							title: nil,
							description: nil,

							year: nil,
							area_id: nil,
							topic_ids: [],

							options: [],

							matched_id: nil,

							start_price: nil,
							bid_up: 0.10,
							reserve_price: nil,

							stock: 1,

							start_date_time: nil,
							end_date_time: nil,

							automatic_renewal: true,
							time_extension: false,

							renewal_count: 0,
							watch_count: 0,				# this count doesn't exist in the legacy model
							visit_count: 0,				# named "view_count" in the legacy model
							
							currency: nil,
							slug: nil,

							pictures: [],
							
							created_at: nil
	end

	defmodule ScheduleAuction do 
		defstruct auction_id: nil, 
							cloned_from_auction_id: nil,
							cloned_to_auction_id: nil,
							seller_id: nil,

							type_id: nil,
							listed_time_id: nil,
							sale_type_id: nil,

							title: nil,
							description: nil,

							year: nil,
							area_id: nil,
							topic_ids: [],

							options: [],

							matched_id: nil,

							start_price: nil,
							bid_up: 0.10,
							reserve_price: nil,

							stock: 1,

							start_date_time: nil,
							end_date_time: nil,

							automatic_renewal: true,
							time_extension: false,

							renewal_count: 0,
							watch_count: 0,				# this count doesn't exist in the legacy model
							visit_count: 0,				# named "view_count" in the legacy model
							
							currency: nil,
							slug: nil,

							pictures: [],
							
							created_at: nil
	end

	defmodule PlaceBid do 
		defstruct auction_id: nil,
							bidder_name: nil,
							bidder_id: nil,
							requested_qty: 1,
							max_value: nil,
							created_at: nil
	end

	defmodule CloseAuction do 
		defstruct auction_id: nil,
							closed_by: nil,
							reason: nil,
							created_at: nil
	end

	defmodule RenewAuction do 
		defstruct auction_id: nil,
							renewed_by: nil,
							start_date_time: nil,
							end_date_time: nil,
							created_at: nil
	end

	defmodule SuspendAuction do 
		defstruct auction_id: nil,
							suspended_by: nil,
							created_at: nil
	end

	defmodule ResumeAuction do 
		defstruct auction_id: nil,
							resumed_by: nil,
							start_date_time: nil,
							end_date_time: nil,
							created_at: nil
	end
	
	defmodule SoldAuction do 
		defstruct auction_id: nil,
							sold_to: nil,
							sold_qty: nil,
							price: nil,
							currency: nil,
							created_at: nil
	end

end