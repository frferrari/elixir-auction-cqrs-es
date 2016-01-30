defmodule Andycot.CommandProcessor.AuctionData do 
	defstruct auction_id: nil,
						duplicated_to_auction_id: nil,
						duplicated_from_auction_id: nil,
						seller_id: nil,
						# buyer_id: nil,
						# current_highest_bidder: nil,

						type_id: nil,
						listed_time_id: nil,
						sale_type_id: nil,

						title: "",
						description: "",

						year: nil,
						area_id: nil,
						topic_ids: [],

						options: [],

						matched_id: nil,

						start_price: nil,
						current_price: nil,
						reserve_price: nil,
						bid_up: nil,
						currency: "",

						original_stock: 1,
						stock: 1,

						start_date_time: nil,
						end_date_time: nil,
						created_at: nil,

						# pending_date: nil,
						automatic_renewal: true,
						time_extension: false,

						renewal_count: 0,
						count_view: 0,

						#
						# closed_by values are
						#
						# nil -> not closed
						# @closed_by_system -> closed by the system
						# is_integer(user_id) -> closed by the user_id
						#
						closed_by: nil,
						is_suspended: false,
						is_sold: false,

						# subtitle: nil,
						slug: "",

						pictures: [],
						bids: [],

						ticker_ref: nil
end
