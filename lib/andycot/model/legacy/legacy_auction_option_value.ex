defmodule Andycot.LegacyAuctionOptionValue do
  use Ecto.Schema

  @primary_key {:auction_id, :id, autogenerate: false}

  schema "auctions_auction_option_value" do
    field :value,	:string
    
    timestamps([{:inserted_at, :created_at}])

    # belongs_to :option_value, Andycot.LegacyOptionValue, foreign_key: :option_value_id, references: :id
    belongs_to :option_value, Andycot.LegacyOptionValue, foreign_key: :option_value_id, references: :id
  end
end
