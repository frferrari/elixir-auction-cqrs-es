defmodule Andycot.Command.User do

	defmodule RegisterUser do 
		defstruct user_id: nil,
							email: "",
							password: "",
							algorithm: nil,
							salt: nil,

							nickname: "",

							#is_active: nil,
							is_super_admin: nil,
							#is_locked: nil,
							is_newsletter: nil,
							is_receive_renewals: nil,

							last_login_at: nil,
							#unsubscribe_at: nil,

							token: nil,

							currency_id: nil,

							last_name: "",
							first_name: "",
							lang: "",
							avatar: nil,
							date_of_birth: nil,
							phone: "",
							mobile: "",
							fax: "",
							description: "",
							sending_country: "",
							invoice_name: "",
							invoice_address1: "",
							invoice_address2: "",
							invoice_zip_code: "",
							invoice_city: "",
							invoice_country: "",
							vat_intra: "",

							holiday_start_at: nil,
							holiday_end_at: nil,
							holiday_hide_id: nil,

							bid_up: nil,

							autotitle_id: nil,
							listed_time_id: nil,

							slug: "",

							created_at: nil
	end

	defmodule ActivateAccount do 
		defstruct user_id: nil,
							activated_at: nil
	end

	defmodule LockAccount do 
		defstruct user_id: nil,
							locked_at: nil
	end

	defmodule UnlockAccount do 
		defstruct user_id: nil,
							unlocked_at: nil
	end
	
	defmodule UnregisterUser do 
		defstruct user_id: nil,
							unregistered_at: nil
	end

	defmodule WatchAuction do
		defstruct user_id: nil,
							auction_id: nil,
							watched_at: nil
	end

	defmodule UnwatchAuction do
		defstruct user_id: nil,
							auction_id: nil,
							unwatched_at: nil
	end

end