defmodule State.Bid do
	defstruct auction_id: nil,
						bidder_id: nil,
						bidder_name: nil,
						requested_qty: nil,
						value: nil,
						max_value: nil,
						is_auto: nil,
						is_visible: nil,
						time_extended: nil,
						created_at: nil
end
