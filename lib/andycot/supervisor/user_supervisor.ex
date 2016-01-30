defmodule Andycot.UserSupervisor do 
	use Supervisor
	import Ecto.Query
	require Logger
	alias Andycot.Repo

	alias Andycot.Command.User.{RegisterUser, UnregisterUser}
	alias Andycot.Command.User.{ActivateAccount, LockAccount, UnlockAccount}
	alias Andycot.Command.User.{WatchAuction, UnwatchAuction}

	alias Andycot.CommandProcessor.User
	
	alias Andycot.Service.UserEmailRegistry
	alias Andycot.Service.UserIdRegistry
	alias Andycot.Service.UserCounter

	@doc """
	"""
	def start_link do
		Logger.info "Starting __MODULE__"

		case Supervisor.start_link(__MODULE__, nil, name: :user_supervisor) do
			{:ok, _} = ok -> 
				start_all_workers
				ok
		end
	end

	@doc """
	"""
	def init(_) do
		Logger.info "Init __MODULE__"

		children = [worker(Andycot.CommandProcessor.User, [], [restart: :transient])]

		supervise(children, strategy: :simple_one_for_one)
	end

	@doc """
	"""
	def start_all_workers(page_number \\ 1) do
		start_chunk_of_workers(page_number, Repo.get_chunk_of_user_events(page_number))
	end

	@doc """
	"""
	def start_chunk_of_workers(_, []) do
		Logger.info "No more User workers to start"
	end

	@doc """
	"""
	def start_chunk_of_workers(page_number, events) do
		Logger.info "Starting User workers for page #{page_number}"

		Enum.map(events, fn(event) -> start_worker(event.user_id) end)
		# Enum.map(events, fn(event) -> spawn fn -> start_worker(event.user_id) end end)

		next_page_number = page_number + 1
		start_chunk_of_workers(next_page_number, Repo.get_chunk_of_user_events(next_page_number))
	end

	@doc """
	"""
	def start_worker(user_id) do
		Logger.info("User #{user_id} starting supervised worker")

		Supervisor.start_child(:user_supervisor, [user_id])
	end

	@doc """
	Registers a user by starting a worker for this user,
	If the user_id given in the command is nil then a new user_id is allocated

	Returns :
	{ :ok, %Fsm.User{%Fsm.User.Data{} = data, state} } 		the registered user in :awaiting_activation state
	{ :error, :already_registered }
	{ :error, :ignore }
	{ :error, reason }
	"""
	def register_user(%RegisterUser{} = command, mode \\ :standard) do
		cond do
			# TODO enhance/add controls
			String.length(command.email) == 0 ->
				{:error, :email_is_empty}

			true ->
				case UserEmailRegistry.add(command.email, command.user_id) do
					{:error, error} ->
						Logger.warn("User #{command.email} couldn't be added to the registry #{error}")
						{:error, error}

					{:ok, new_user_id} ->
						case start_worker(new_user_id) do
							{:ok, pid} -> 
								GenServer.call(pid, {:register_user, %RegisterUser{command | user_id: new_user_id}, mode})

							{:error, {:already_started, _}} ->
								Logger.warn("User #{command.email} is already registered")
								{:error, :already_registered}

							{:error, reason} -> 
								Logger.warn("User #{command.email} could not be registered reason")
								IO.inspect reason
								{:error, reason}
						end
				end
		end
	end

	@doc """
	Returns :
	{ :ok, %Fsm.User{%Fsm.User.Data{} = data, state} }
	{ :error, :unknown_user }
	"""
	def activate_account(%ActivateAccount{} = command, mode \\ :standard) do
		if :undefined == User.whereis(command.user_id) do
			{:error, :unknown_user}
		else
			{:ok, fsm} = GenServer.call(User.via_tuple(command.user_id), {:activate_account, command, mode})
		end
	end

	@doc """
	Returns :
	{ :ok, %Fsm.User{%Fsm.User.Data{} = data, state} }
	{ :error, :unknown_user }
	"""
	def lock_account(%LockAccount{} = command, mode \\ :standard) do
		if :undefined == User.whereis(command.user_id) do
			{:error, :unknown_user}
		else
			{:ok, fsm} = GenServer.call(User.via_tuple(command.user_id), {:lock_account, command, mode})
		end
	end

	@doc """
	Returns :
	{ :ok, %Fsm.User{%Fsm.User.Data{} = data, state} }
	{ :error, :unknown_user }
	"""
	def unlock_account(%UnlockAccount{} = command, mode \\ :standard) do
		if :undefined == User.whereis(command.user_id) do
			{:error, :unknown_user}
		else
			{:ok, fsm} = GenServer.call(User.via_tuple(command.user_id), {:unlock_account, command, mode})
		end
	end

	@doc """
	Returns :
	:ok
	:unknown_user
	"""
	def unregister_user(%UnregisterUser{} = command, mode \\ :standard) do
		if :undefined == User.whereis(command.user_id) do
			:unknown_user
		else
			:ok = GenServer.call(User.via_tuple(command.user_id), {:unregister_user, command, mode})
		end
	end

	@doc """
	A user adds an auction to its list of favorite auctions

	Returns :
	:ok
	:unknown_user
	"""
	def watch_auction(%WatchAuction{} = command, mode \\ :standard) do
		if :undefined == User.whereis(command.user_id) do
			:unknown_user
		else
			:ok = GenServer.cast(User.via_tuple(command.user_id), {:watch_auction, command, mode})
		end
	end

	@doc """
	A user removes an auction from its list of favorite auctions
	
	Returns :
	{ :ok, %Fsm.User{%Fsm.User.Data{} = data, state} }
	{ :error, :unknown_user }
	"""
	def unwatch_auction(%UnwatchAuction{} = command, mode \\ :standard) do
		if :undefined == User.whereis(command.user_id) do
			:unknown_user
		else
			:ok = GenServer.cast(User.via_tuple(command.user_id), {:unwatch_auction, command, mode})
		end
	end

	@doc """
	Get a user given its id

	Returns :
	{ :ok, %Fsm.User{%Fsm.User.Data{] = data, state}} }
	{ :error, :unknown_user }
	"""
	def get_user(user_id) do
		#
		# TODO refactor
		#
		if :undefined == User.whereis(user_id) do
			{:error, :unknown_user}
		else
			{:ok, GenServer.call(User.via_tuple(user_id), :get_user)}
		end
	end

	@doc """
	"""
	def can_bid?(user_id, :legacy = mode) do
		true
	end

	def can_bid?(user_id, mode) do
		#
		# TODO refactor
		#
		if :undefined == User.whereis(user_id) do
			false
		else
			GenServer.call(User.via_tuple(user_id), :can_bid)
		end
	end

	@doc """
	"""
	def can_receive_bids?(user_id, :legacy = mode) do
		true
	end

	def can_receive_bids?(user_id, mode) do
		#
		# TODO refactor
		#
		if :undefined == User.whereis(user_id) do
			false
		else
			GenServer.call(User.via_tuple(user_id), :can_receive_bids)
		end
	end

	@doc """
	"""
	def is_super_admin?(user_id, mode) do
		if :undefined == User.whereis(user_id) do
			false
		else
			GenServer.call(User.via_tuple(user_id), :is_super_admin)
		end
	end

end
