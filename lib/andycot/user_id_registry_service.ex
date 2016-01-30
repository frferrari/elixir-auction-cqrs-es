defmodule Andycot.Service.UserIdRegistry do
  use ExActor.GenServer, export: __MODULE__
  alias Andycot.Service.UserCounter

  defstart start_link, do: initial_state(:ets.new(__MODULE__, [:named_table, {:keypos, 1}]))

  @doc """
  Returns:
  """
  defcall check(user_id), state: table do
    reply(lookup(table, user_id))
  end

  @doc """
  Returns:
  {:ok, true}
  {:error, :already_exists}
  """
  defcall add(email, user_id), state: table do
    case lookup(table, user_id) do
      false ->
        insert_return_status = :ets.insert(table, {user_id, email})
        set_and_reply(table, {:ok, email})
        
      _ ->
        reply({:error, :already_registered})
    end
  end

  #
  # Lookup for an existing user_id in the ETS table and returns
  # - the user's id when the user_id was found
  # - false when the user_id wasn't found
  #
  defp lookup(table, user_id) do
    case :ets.lookup(table, user_id) do
      [{^user_id, email}] -> email
      [] -> false
    end
  end

end
