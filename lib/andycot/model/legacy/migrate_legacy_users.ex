#
# curl -XGET localhost:9200/auctions/article/1
#
# curl -XPOST 'localhost:9200/auctions/article/1/_update' -d '{
# "script": { "id": "viewAuctionsAppendTopicId", "lang": "groovy" }, "params": { "new_topic_id": 1900 }
# }'
#

defmodule Andycot.MigrateLegacy.Users do
	@page_size 200

	import Ecto.Query
	import Ecto.Type

	import Andycot.Tools.Timestamp
	alias Andycot.LegacyRepo
	alias Andycot.LegacyUser
	alias Andycot.Command.User.{RegisterUser, ActivateAccount, LockAccount, UnlockAccount, UnregisterUser}
	alias Andycot.UserSupervisor

	defp get_users_query() do
		from a in LegacyUser
	end

	defp get_users_query(limit, offset) do
		from a in LegacyUser, select: a.id, limit: ^limit, offset: ^offset, order_by: [asc: :id]
	end

	@doc "Get a count of the auctions in the legacy database"
	def get_users_count do
		(from c in get_users_query(), select: count(c.id)) |> LegacyRepo.all
	end

	@doc "Get a list of users from the legacy database given a page number"
	def get_users(page_number) do
		offset = @page_size * (page_number - 1)

		query = from a in LegacyUser,
			select: a,
			limit: ^@page_size,
			offset: ^offset,
			order_by: [asc: :id]

		query |> LegacyRepo.all 
	end

	@doc "Migrate all users from the legacy database"
	def migrate_all(page_number \\ 1) do
		migrate_page(page_number, get_users(page_number))
	end

	defp migrate_page(_page_number, []) do
		IO.puts "Migration finished"
	end

	defp migrate_page(page_number, users) do
		IO.puts "Migrating users for page #{page_number}"

		for user <- users do

			register_command = %RegisterUser{
				user_id: user.id,
				email: user.username,
				password: user.password,
				algorithm: user.algorithm,
				salt: user.salt,

				nickname: user.nickname,

				is_super_admin: user.is_super_admin,
				is_newsletter: user.is_newsletter,
				is_receive_renewals: user.is_receive_renewals,

				last_login_at: user.last_login |> ecto_date_to_timestamp,

				token: user.token,

				currency_id: user.currency_id,

				last_name: user.last_name,
				first_name: user.first_name,
				lang: user.culture,
				avatar: user.avatar,
				date_of_birth: user.date_of_birth |> ecto_date_to_timestamp,
				phone: user.phone,
				mobile: user.mobile,
				fax: user.fax,
				description: user.description,
				sending_country: user.sending_country,
				invoice_name: user.invoice_name,
				invoice_address1: user.invoice_address1,
				invoice_address2: user.invoice_address2,
				invoice_zip_code: user.invoice_zip_code,
				invoice_city: user.invoice_city,
				invoice_country: user.invoice_country,
				vat_intra: user.vat_intra,

				holiday_start_at: user.holiday_start |> ecto_date_to_timestamp,
				holiday_end_at: user.holiday_end |> ecto_date_to_timestamp,
				holiday_hide_id: user.holiday_hide_id,

				bid_up: user.bidding_up |> decimal_to_string,

				autotitle_id: user.autotitle_id,
				listed_time_id: user.listed_time_id,

				slug: user.slug,

				created_at: user.created_at |> ecto_date_to_timestamp
			}

			# Create the user
			{:ok, registered_user} = register_command 
			|> UserSupervisor.register_user

			# Activate the user
			%ActivateAccount{user_id: registered_user.data.user_id, activated_at: register_command.created_at}
			|> UserSupervisor.activate_account

			# Locked user
			if user.is_locked do
				%LockAccount{user_id: registered_user.data.user_id, locked_at: user.updated_at |> ecto_date_to_timestamp}
				|> UserSupervisor.lock_account
			end

			# Unregistered user
			if user.unsubscribe_at != nil do
				%UnregisterUser{user_id: registered_user.data.user_id, unregistered_at: user.updated_at |> ecto_date_to_timestamp}
				|> UserSupervisor.unregister_user
			end
		end

		next_page_number = page_number + 1
		migrate_page(next_page_number, get_users(next_page_number))
	end

	defp decimal_to_string(value) do
		if value == nil do
			""
		else 
			value |> Decimal.to_string(:normal)
		end
	end

	defp ecto_date_to_timestamp(ecto_date) do
		if ecto_date != nil do
			ecto_date |> Ecto.DateTime.to_erl |> Andycot.Tools.Timestamp.to_timestamp
		else
			nil
		end
	end

end
