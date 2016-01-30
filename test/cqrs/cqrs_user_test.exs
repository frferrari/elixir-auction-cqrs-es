defmodule Cqrs.User.Test do
	use ExUnit.Case, async: false
	alias Andycot.UserSupervisor
	import Andycot.Tools.Timestamp
  alias Andycot.Command.User.{RegisterUser, ActivateAccount, LockAccount, UnlockAccount, UnregisterUser}

	def random_string(length \\ 16) do
	  :crypto.strong_rand_bytes(length) |> Base.url_encode64 |> binary_part(0, length)
	end

	setup_all do
		{:ok, [	mode: :standard, 
						email1: "contact1@andycot.fr",
						email2: "contact2@andycot.fr",
						register_user_command: %{	user_id: nil,
																			email: "contact@andycot.fr",
																			password: "mypassword",
																			algorithm: "sha128",
																			salt: "mysalt",
																			nickname: "mynickname",
																			is_super_admin: "issuperadmin",
																			is_newsletter: "isnewsletter",
																			is_receive_renewals: "isreceiverenewals",
																			last_login_at: now(),
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
																			holiday_start_at: now(),
																			holiday_end_at: now()+3600,
																			holiday_hide_id: 1,
																			bid_up: 0.10,
																			autotitle_id: 2,
																			listed_time_id: 3,
																			slug: "myslug",
																			created_at: now()
																		}
					]}
	end

	#setup context do
	#	:ok
	#end

	@tag :one
	test "It should fail when registering an already registered email", context do
		now = now()

		register_user_command = %{context[:register_user_command] | created_at: now, 
																																holiday_start_at: now,
																																holiday_end_at: now+3600,
																																last_login_at: now}

		{:ok, fsm} = UserSupervisor.register_user(struct(RegisterUser, register_user_command), context[:mode])

		{:error, :already_registered} = UserSupervisor.register_user(struct(RegisterUser, register_user_command), context[:mode])

	end

	@tag :one
	test "It should fail when registering with an empty email", context do
		now = now()

		register_user_command = %{context[:register_user_command] | created_at: now, 
																																holiday_start_at: now,
																																holiday_end_at: now+3600,
																																last_login_at: now,
																																email: ""}

		{:error, :email_is_empty} = UserSupervisor.register_user(struct(RegisterUser, register_user_command), context[:mode])

	end

	@tag :one
	test "It should fail when locking an inactive account", context do
		now = now()

		#
		# Register the user
		#
		register_user_command = %{context[:register_user_command] | created_at: now, 
																																holiday_start_at: now,
																																holiday_end_at: now+3600,
																																last_login_at: now,
																																email: random_string}

		{:ok, fsm} = UserSupervisor.register_user(struct(RegisterUser, register_user_command), context[:mode])
		
		{:ok, %Fsm.User{state: :awaiting_activation}} = UserSupervisor.lock_account(%LockAccount{user_id: fsm.data.user_id})

	end

	@tag :one
	test "It should fail when activating an account for an unknown user" do

		{:error, :unknown_user} = UserSupervisor.activate_account(%ActivateAccount{user_id: 1000})

	end

	@tag :one
	test "It should fail when locking an account for an unknown user" do

		{:error, :unknown_user} = UserSupervisor.lock_account(%LockAccount{user_id: 1000})

	end

	@tag :one
	test "It should fail when unregistering an unknown user" do

		{:error, :unknown_user} = UserSupervisor.unregister_user(%UnregisterUser{user_id: 1000})

	end

	@tag :one
	test "It should succeed when registering and activating a new user", context do
		now = now()
		email = random_string

		context_register_user_command = context[:register_user_command]

		#
		# Register the user
		#
		register_user_command = %{context[:register_user_command] | created_at: now, 
																																holiday_start_at: now,
																																holiday_end_at: now+3600,
																																last_login_at: now,
																																email: email}

		{:ok, %Fsm.User{data: %Fsm.User.Data{user_id: user_id} = data, state: state}} = UserSupervisor.register_user(struct(RegisterUser, register_user_command), context[:mode])

		assert state == :awaiting_activation

		assert data.user_id == user_id
		assert data.email == email
		assert data.password == context_register_user_command.password
		assert data.algorithm == context_register_user_command.algorithm
		assert data.salt == context_register_user_command.salt
		assert data.nickname == context_register_user_command.nickname
		assert data.is_super_admin == context_register_user_command.is_super_admin
		assert data.is_newsletter == context_register_user_command.is_newsletter
		assert data.is_receive_renewals == context_register_user_command.is_receive_renewals
		assert data.token == context_register_user_command.token
		assert data.currency_id == context_register_user_command.currency_id
		assert data.last_name == context_register_user_command.last_name
		assert data.first_name == context_register_user_command.first_name
		assert data.lang == context_register_user_command.lang
		assert data.avatar == context_register_user_command.avatar
		assert data.date_of_birth == context_register_user_command.date_of_birth
		assert data.phone == context_register_user_command.phone
		assert data.mobile == context_register_user_command.mobile
		assert data.fax == context_register_user_command.fax
		assert data.description == context_register_user_command.description
		assert data.sending_country == context_register_user_command.sending_country
		assert data.invoice_name == context_register_user_command.invoice_name
		assert data.invoice_address1 == context_register_user_command.invoice_address1
		assert data.invoice_address2 == context_register_user_command.invoice_address2
		assert data.invoice_zip_code == context_register_user_command.invoice_zip_code
		assert data.invoice_city == context_register_user_command.invoice_city
		assert data.invoice_country == context_register_user_command.invoice_country
		assert data.vat_intra == context_register_user_command.vat_intra
		assert data.holiday_hide_id == context_register_user_command.holiday_hide_id
		assert data.bid_up == context_register_user_command.bid_up
		assert data.autotitle_id == context_register_user_command.autotitle_id
		assert data.listed_time_id == context_register_user_command.listed_time_id
		assert data.slug == context_register_user_command.slug

		assert data.last_login_at == register_user_command.last_login_at
		assert data.created_at == register_user_command.created_at
		assert data.holiday_start_at == register_user_command.holiday_start_at
		assert data.holiday_end_at == register_user_command.holiday_end_at

		#
		# Activate the user account
		#
		{:ok, %Fsm.User{} = fsm_activated_account} = UserSupervisor.activate_account(%ActivateAccount{user_id: user_id, activated_at: now})
		assert fsm_activated_account.state == :active

		#
		# It is forbidden to register with an already registered user_id
		#
		{:error, :already_registered} = UserSupervisor.register_user(struct(RegisterUser, %{register_user_command | user_id: user_id}), context[:mode])

	end

	@tag :one
	test "It should succeed when unregistering an active user", context do
		now = now()

		register_user_command = %{context[:register_user_command] | created_at: now, 
																																holiday_start_at: now,
																																holiday_end_at: now+3600,
																																last_login_at: now,
																																email: random_string}

		{:ok, fsm} = UserSupervisor.register_user(struct(RegisterUser, register_user_command), context[:mode])

		{:ok, %Fsm.User{state: :active}} = UserSupervisor.activate_account(%ActivateAccount{user_id: fsm.data.user_id, activated_at: now})

		{:ok, fsm} = UserSupervisor.unregister_user(%UnregisterUser{user_id: fsm.data.user_id})
		assert fsm.data.unregistered_at != nil

	end

	@tag :one
	test "It should succeed when locking an active account", context do
		now = now()

		#
		# Register the user
		#
		register_user_command = %{context[:register_user_command] | created_at: now, 
																																holiday_start_at: now,
																																holiday_end_at: now+3600,
																																last_login_at: now,
																																email: random_string}

		{:ok, fsm} = UserSupervisor.register_user(struct(RegisterUser, register_user_command), context[:mode])

		{:ok, %Fsm.User{state: :active}} = UserSupervisor.activate_account(%ActivateAccount{user_id: fsm.data.user_id, activated_at: now})

		{:ok, fsm} = UserSupervisor.lock_account(%LockAccount{user_id: fsm.data.user_id})
		assert fsm.data.locked_at != nil

	end

	@tag :one
	test "It should succeed when unlocking a locked account", context do
		now = now() - 3600

		#
		# Register the user
		#
		register_user_command = %{context[:register_user_command] | created_at: now, 
																																holiday_start_at: now,
																																holiday_end_at: now+3600,
																																last_login_at: now,
																																email: random_string}

		{:ok, registered_fsm} = UserSupervisor.register_user(struct(RegisterUser, register_user_command), context[:mode])

		{:ok, %Fsm.User{state: :active}} = UserSupervisor.activate_account(%ActivateAccount{user_id: registered_fsm.data.user_id, activated_at: now})

		{:ok, fsm} = UserSupervisor.lock_account(%LockAccount{user_id: registered_fsm.data.user_id})
		assert fsm.data.locked_at != nil

		{:ok, fsm} = UserSupervisor.unlock_account(%UnlockAccount{user_id: registered_fsm.data.user_id, unlocked_at: now})
		assert fsm.data.locked_at == nil
		assert fsm.data.activated_at == now

	end

	@tag :one
	test "It should succeed when unregistering a locked account", context do
		now = now() - 3600

		#
		# Register the user
		#
		register_user_command = %{context[:register_user_command] | created_at: now, 
																																holiday_start_at: now,
																																holiday_end_at: now+3600,
																																last_login_at: now,
																																email: random_string}

		{:ok, registered_fsm} = UserSupervisor.register_user(struct(RegisterUser, register_user_command), context[:mode])

		{:ok, %Fsm.User{state: :active} = activated_fsm} = UserSupervisor.activate_account(%ActivateAccount{user_id: registered_fsm.data.user_id, activated_at: now})

		{:ok, locked_fsm} = UserSupervisor.lock_account(%LockAccount{user_id: registered_fsm.data.user_id})
		assert locked_fsm.data.locked_at != nil

		{:ok, fsm} = UserSupervisor.unregister_user(%UnregisterUser{user_id: registered_fsm.data.user_id, unregistered_at: now})
		assert fsm.data.unregistered_at == now
		assert fsm.data.activated_at == activated_fsm.data.activated_at

	end

end
