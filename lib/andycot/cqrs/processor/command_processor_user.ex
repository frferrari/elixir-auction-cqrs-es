defmodule Andycot.CommandProcessor.User do 
	@moduledoc """
	"""
	use ExActor.GenServer

  alias Andycot.Repo
  alias Andycot.AuctionSupervisor

	import Andycot.Tools.Timestamp
  import Andycot.EventProcessor.User
  
  alias Andycot.Command.User.{RegisterUser, UnregisterUser}
  alias Andycot.Command.User.{ActivateAccount, LockAccount, UnlockAccount}
  alias Andycot.Command.User.{WatchAuction, WatchRejected, UnwatchAuction}

  alias Andycot.Service.RegisterUserEmail
	require Logger

	defstart start_link(user_id), gen_server_opts: [name: via_tuple(user_id)] do

    hibernate

    Fsm.User.new
    |> replay_events(user_id)
    |> initial_state

	end

  @doc """
  Handler for the register_user command. When registered a user must activate its account.
  """
  defcall register_user(%RegisterUser{} = command, mode), state: fsm do
		Logger.info("User #{command.user_id} Registering")

    updated_command = if command.created_at == nil do
      %RegisterUser{command | created_at: now()}
    else
      command
    end

    {:ok, new_fsm} = make_user_registered_event(updated_command)
    |> apply_event(fsm, mode)

		set_and_reply(new_fsm, {:ok, new_fsm})
  end

  @doc """
  Handler for the activate account command, this is the natural step after registering a user.
  """
  defcall activate_account(%ActivateAccount{} = command, mode), state: fsm do
  	Logger.info("User #{command.user_id} Activating account")

    updated_command = if command.activated_at == nil do
      %ActivateAccount{command | activated_at: now()}
    else
      command
    end

    {:ok, new_fsm} = make_account_activated_event(updated_command)
    |> apply_event(fsm, mode)

    set_and_reply(new_fsm, {:ok, new_fsm})
  end

  @doc """
  Handler for the lock account command.
  """
  defcall lock_account(%LockAccount{} = command, mode), state: fsm do
    Logger.info("User #{command.user_id} Locking account")

    updated_command = if command.locked_at == nil do
      %LockAccount{command | locked_at: now()}
    else
      command
    end

    {:ok, new_fsm} = make_account_locked_event(updated_command)
    |> apply_event(fsm, mode)

    set_and_reply(new_fsm, {:ok, new_fsm})
  end

  @doc """
  Handler for the unlock account command.
  """
  defcall unlock_account(%UnlockAccount{} = command, mode), state: fsm do
    Logger.info("User #{command.user_id} Unlocking account")

    updated_command = if command.unlocked_at == nil do
      %UnlockAccount{command | unlocked_at: now()}
    else
      command
    end

    {:ok, new_fsm} = make_account_unlocked_event(updated_command)
    |> apply_event(fsm, mode)

    set_and_reply(new_fsm, {:ok, new_fsm})
  end

  @doc """
  Handler for the unregister command.
  """
  defcall unregister_user(%UnregisterUser{} = command, mode), state: fsm do
    Logger.info("User #{command.user_id} Unregistering user")

    updated_command = if command.unregistered_at == nil do
      %UnregisterUser{command | unregistered_at: now()}
    else
      command
    end

    {:ok, new_fsm} = make_user_unregistered_event(updated_command)
    |> apply_event(fsm, mode)

    set_and_reply(new_fsm, {:ok, new_fsm})
  end

  @doc """
  A user adds an auction to its list of favorite auctions
  """
  defcast watch_auction(%WatchAuction{} = command, mode), state: fsm do
    Logger.info("User #{command.user_id} Watch auction #{command.auction_id}")

    updated_command = if command.watched_at == nil do
      %WatchAuction{command | watched_at: now()}
    else
      command
    end

    {status, updated_fsm, event} = cond do

      MapSet.member?(fsm.data.watched_auctions, command.auction_id) ->
        # An auction can be watched only once per user (this way we keep an accurate watch_count value)
        {:error, fsm, make_watch_rejected_event(updated_command, %{reason: :already_watching})}

      true ->
        {:ok, fsm, make_auction_watched_event(updated_command)}

    end

    {:ok, new_fsm} = apply_event(event, updated_fsm, mode)

    if status == :ok, do: AuctionSupervisor.increment_watch_count(command.auction_id)

    new_state(new_fsm)
  end

  @doc """
  A user removes an auction from its list of favorite auctions
  """
  defcast unwatch_auction(%UnwatchAuction{} = command, mode), state: fsm do
    Logger.info("User #{command.user_id} Unwatch auction #{command.auction_id}")

    updated_command = if command.unwatched_at == nil do
      %UnwatchAuction{command | unwatched_at: now()}
    else
      command
    end

    {:ok, new_fsm} = make_auction_unwatched_event(updated_command)
    |> apply_event(fsm, mode)

    AuctionSupervisor.decrement_watch_count(command.auction_id)

    new_state(new_fsm)
  end

  @doc """
  """
  defcall get_user, state: fsm do
  	reply(fsm)
  end

  @doc """
  """
  defcall can_bid, state: fsm do
    if fsm.data.activated_at != nil and fsm.data.unregistered_at == nil and fsm.data.locked_at == nil do
      reply(true)
    else
      reply(false)
    end
  end

  @doc """
  """
  defcall can_receive_bids, state: fsm do
    if fsm.data.activated_at != nil and fsm.data.unregistered_at == nil and fsm.data.locked_at == nil do
      reply(true)
    else
      reply(false)
    end
  end

  @doc """
  """
  defcall is_super_admin, state: fsm do
    reply(fsm.data.is_super_admin || false)
  end

  @doc """
  """
  def whereis(user_id) do
    worker_name(user_id)
    |> :global.whereis_name
  end

  @doc """
  """
  def via_tuple(user_id) do
    # {:via, :gproc, {:n, :l, {:user_worker, worker_name(user_id)} }}
    # {:via, :gproc, {:n, :l, {:user_worker, {:user, user_id}} }}
    # {:global, {:user_worker, {:user, user_id}} }
    {:global, worker_name(user_id)}
  end

  @doc """
  Generates a unique worker name
  """
  def worker_name(user_id) do
    {:user_worker, user_id}
  end

end
