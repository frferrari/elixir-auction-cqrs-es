defmodule Andycot.Service.UserEmailRegistry do
  use ExActor.GenServer, export: __MODULE__
  alias Andycot.Service.UserCounter
  alias Andycot.Service.UserIdRegistry

  defstart start_link, do: initial_state(:ets.new(__MODULE__, [:named_table, {:keypos, 1}]))

  @doc """
  Returns:
  false   when the user_id isn't found in the ETS table
  1..n    an integer representing the user's id found in the ETS table
  """
  defcall check(email), state: table do
    reply(lookup(table, email))
  end

  @doc """
  Returns:
  {:ok, true}
  {:error, :already_exists}
  """
  defcall add(email, user_id \\ nil), state: table do
    case lookup(table, email) do
      false ->
        new_user_id = user_id || UserCounter.get_next()
        insert_return_status = :ets.insert(table, {email, new_user_id})
        UserIdRegistry.add(email, new_user_id)
        set_and_reply(table, {:ok, new_user_id})
        
      _ ->
        reply({:error, :already_registered})
    end
  end

  #
  # Lookup for an existing user_id in the ETS table and returns
  # - the user's id when the user_id was found
  # - false when the user_id wasn't found
  #
  defp lookup(table, email) do
    case :ets.lookup(table, email) do
      [{^email, user_id}] -> user_id
      [] -> false
    end
  end

end
