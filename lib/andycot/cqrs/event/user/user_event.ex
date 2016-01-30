defmodule Andycot.Event.User do

	defmodule UserRegistered do 
		defstruct user_id: nil,
							email: nil,
							password: nil,
							algorithm: nil,
							salt: nil,

							nickname: nil,

							#is_active: nil,
							is_super_admin: nil,
							#is_locked: nil,
							is_newsletter: nil,
							is_receive_renewals: nil,

							last_login_at: nil,
							#unsubscribe_at: nil,

							token: nil,

							currency_id: nil,

							last_name: nil,
							first_name: nil,
							lang: nil,
							avatar: nil,
							date_of_birth: nil,
							phone: nil,
							mobile: nil,
							fax: nil,
							description: nil,
							sending_country: nil,
							invoice_name: nil,
							invoice_address1: nil,
							invoice_address2: nil,
							invoice_zip_code: nil,
							invoice_city: nil,
							invoice_country: nil,
							vat_intra: nil,

							holiday_start_at: nil,
							holiday_end_at: nil,
							holiday_hide_id: nil,

							bid_up: nil,

							autotitle_id: nil,
							listed_time_id: nil,

							slug: nil,

							created_at: nil
	end

	defmodule AccountActivated do 
		defstruct user_id: nil,
							activated_at: nil
	end

	defmodule AccountLocked do 
		defstruct user_id: nil,
							locked_at: nil
	end

	defmodule AccountUnlocked do 
		defstruct user_id: nil,
							unlocked_at: nil
	end

	defmodule UserUnregistered do 
		defstruct user_id: nil,
							unregistered_at: nil
	end

	defmodule AuctionWatched do
		defstruct user_id: nil,
							auction_id: nil,
							watched_at: nil
	end

	defmodule WatchRejected do
		defstruct user_id: nil,
							auction_id: nil,
							reason: nil,
							watched_at: nil
	end

	defmodule AuctionUnwatched do
		defstruct user_id: nil,
							auction_id: nil,
							unwatched_at: nil
	end

end