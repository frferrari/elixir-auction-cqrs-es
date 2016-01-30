defmodule Andycot.LegacyBid do
  use Ecto.Schema

  schema "auctions_bid" do
  	field :auction_id, 								:integer
    field :value,											:decimal
    field :max_value,									:decimal
    field :auction_snapshot_price,		:decimal
    field :is_auto,         					:boolean
    field :is_visible,       					:boolean
    timestamps([{:inserted_at, :created_at}])

    belongs_to :user, Andycot.LegacyUser, foreign_key: :user_id
  end
end
