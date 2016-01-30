defmodule Andycot.EventProcessor.User do 
	@moduledoc """
	"""

	require Logger
	import Andycot.Tools.Timestamp

	alias Andycot.Repo

	alias Andycot.Command.User.{RegisterUser, UnregisterUser}
	alias Andycot.Command.User.{ActivateAccount, LockAccount, UnlockAccount}
	alias Andycot.Command.User.{WatchAuction, UnwatchAuction}

	alias Andycot.Event.User.{UserRegistered, UserUnregistered}
	alias Andycot.Event.User.{AccountActivated, AccountLocked, AccountUnlocked}
	alias Andycot.Event.User.{AuctionWatched, WatchRejected, AuctionUnwatched}

	alias Decimal, as: D

	@doc """
	"""
	def replay_events(fsm, user_id) do
		Logger.info "User #{user_id} replay all events"

		Repo.get_user_events(user_id)
		|> Enum.map(fn {event_type, event_data} -> {event_type, atom_keys(event_data)} end)
		|> replay_next_event(fsm)
	end

	@doc """
	Handles the replay of the next event
	"""
	def replay_next_event([head|tail], fsm) do
		{event_type, event_data} = head

		Logger.info("User #{event_data.user_id} NEXT event to replay #{event_type}")

		{:ok, new_fsm} = replay_event(event_type, event_data, :replay, fsm)

		replay_next_event(tail, new_fsm)
	end

	@doc """
	Handles the replay of the next event
	Helps to stop the recursion when the list of events to replay is empty
	"""
	def replay_next_event([], fsm) do
		fsm
	end

	#
	# Generates functions that applies an event based on the event name
	#
	for event <- ["Elixir.Andycot.Event.User.UserRegistered",
								"Elixir.Andycot.Event.User.UserUnregistered",
								"Elixir.Andycot.Event.User.AccountActivated",
								"Elixir.Andycot.Event.User.AccountLocked",
								"Elixir.Andycot.Event.User.AccountUnlocked",
								"Elixir.Andycot.Event.User.AuctionWatched",
								"Elixir.Andycot.Event.User.WatchRejected",
								"Elixir.Andycot.Event.User.AuctionUnwatched"
							 ] do
		def replay_event(event = event_type, event_data, mode, fsm) do
			Logger.info("User #{event_data.user_id}   replaying event #{event_type} mode #{mode}")
			apply_event(struct(String.to_atom(event), event_data), fsm, mode)
		end
	end

	def replay_event(event_type, event_data, mode, fsm) do
		Logger.error("User #{event_data.user_id}   unhandled event #{event_type} mode #{mode}")
		{nil, nil, fsm}
	end

	@doc """
	Process the auction related events

	Returns : 
	{ :nack, event.reason}
	"""
	def apply_event(event, fsm, mode \\ :standard)

	def apply_event(%UserRegistered{} = event, fsm, mode) do
		Logger.info("User #{event.user_id}   applying event UserRegistered")

		new_fsm = fsm |> Fsm.User.user_registered(event, mode)

		{:ok, new_fsm}
	end

	def apply_event(%AccountActivated{} = event, fsm, mode) do
		Logger.info("User #{event.user_id}   applying event AccountActivated")

		new_fsm = fsm |> Fsm.User.account_activated(event, mode)

		{:ok, new_fsm}
	end

	def apply_event(%UserUnregistered{} = event, fsm, mode) do
		Logger.info("User #{event.user_id}   applying event UserUnregistered")

		new_fsm = fsm |> Fsm.User.user_unregistered(event, mode)

		{:ok, new_fsm}
	end

	def apply_event(%AccountLocked{} = event, fsm, mode) do
		Logger.info("User #{event.user_id}   applying event AccountLocked")

		new_fsm = fsm |> Fsm.User.account_locked(event, mode)

		{:ok, new_fsm}
	end

	def apply_event(%AccountUnlocked{} = event, fsm, mode) do
		Logger.info("User #{event.user_id}   applying event AccountUnlocked")

		new_fsm = fsm |> Fsm.User.account_unlocked(event, mode)

		{:ok, new_fsm}
	end

	def apply_event(%AuctionWatched{} = event, fsm, mode) do
		Logger.info("User #{event.user_id}   applying event AuctionWatched")

		new_fsm = fsm |> Fsm.User.auction_watched(event, mode)

		{:ok, new_fsm}
	end

	def apply_event(%WatchRejected{} = event, fsm, mode) do
		Logger.info("User #{event.user_id}   applying event WatchRejected")

		new_fsm = fsm |> Fsm.User.watch_rejected(event, mode)

		{:ok, new_fsm}
	end

	def apply_event(%AuctionUnwatched{} = event, fsm, mode) do
		Logger.info("User #{event.user_id}   applying event AuctionUnwatched")

		new_fsm = fsm |> Fsm.User.auction_unwatched(event, mode)

		{:ok, new_fsm}
	end

	@doc """
	Helper function used when merging two maps where we want to keep the values of the map given as the right parameter
	"""
	def map_merge_keep_right(_k, vl, vr) do
		vr || vl
	end

	@doc """
	"""
	def make_user_registered_event(%RegisterUser{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(UserRegistered, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_user_unregistered_event(%UnregisterUser{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(UserUnregistered, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_account_activated_event(%ActivateAccount{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(AccountActivated, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_account_locked_event(%LockAccount{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(AccountLocked, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_account_unlocked_event(%UnlockAccount{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(AccountUnlocked, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_auction_watched_event(%WatchAuction{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(AuctionWatched, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_watch_rejected_event(%WatchAuction{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(WatchRejected, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def make_auction_unwatched_event(%UnwatchAuction{} = command, overwrite \\ %{}) do
		Map.merge(command, struct(AuctionUnwatched, overwrite), &map_merge_keep_right/3)
	end

	@doc """
	"""
	def atom_keys(the_map) do
		for {key, val} <- the_map, into: %{}, do:	{String.to_atom(key), val}
	end

end
