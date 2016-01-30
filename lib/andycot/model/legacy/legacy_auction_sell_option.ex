defmodule Andycot.LegacyAuctionSellOption do
  use Ecto.Schema

  @primary_key {:auction_id, :id, autogenerate: false}
  
  schema "auctions_auction_sell_option" do
    field :option_id,       :integer
    field :site_price,      :decimal
    field :is_bill,					:boolean
    timestamps([{:inserted_at, :created_at}])
  end
end
