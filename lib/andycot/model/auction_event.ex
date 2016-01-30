defmodule Andycot.Model.AuctionEvent do 
	use Ecto.Model
	import Ecto.Query
	import Andycot.Tools.Timestamp

	@primary_key {:id, :binary_id, autogenerate: true}
	schema "auction_events" do
		field :event_type, :string
		field :event_data, :map
		field :auction_id, :integer

		field :created_at, :integer
		#timestamps([inserted_at: :created_at, updated_at: false])
	end

	@doc """
	Generates and returns an Event.Auction event with the given date/time as timestamp.
	Used during the replay phase to keep the created_at field value of the original auctions.
	"""
	def make_event(event_type, event_data, :replay) do
		created_at = event_data |> Map.get(:created_at)
		data = event_data |> Map.delete(:created_at)

		%__MODULE__{event_type: Atom.to_string(event_type),
								auction_id: event_data.auction_id,
								created_at: created_at,
								event_data: data}
	end

	@doc """
	Generates and returns an Event.Auction event with the given date/time as timestamp.
	Used during the migration phase to keep the created_at field value of the original auctions.
	"""
	def make_event(event_type, event_data, :legacy) do
		created_at = event_data |> Map.get(:created_at)
		data = event_data |> Map.delete(:created_at)

		%__MODULE__{event_type: Atom.to_string(event_type),
								auction_id: event_data.auction_id,
								created_at: created_at,
								event_data: data}
	end

	@doc """
	Generates and returns an Event.Auction event with the given date/time as timestamp.
	Used in `:standard` mode
	"""
	def make_event(event_type, event_data, :standard) do
		%__MODULE__{event_type: Atom.to_string(event_type), 
								auction_id: event_data.auction_id, 
								created_at: now(),
								event_data: event_data}
	end
end
