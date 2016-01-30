defmodule Fsm.User.Data do 
	@moduledoc """
	"""
	defstruct user_id: nil,
						email: nil,
						password: nil,
						algorithm: nil,
						salt: nil,

						nickname: nil,

						activated_at: nil,
						locked_at: nil,

						is_super_admin: nil,
						is_newsletter: nil,
						is_receive_renewals: nil,

						last_login_at: nil,
						unregistered_at: nil,

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

						watched_auctions: [],

						created_at: nil,
						updated_at: nil
end
