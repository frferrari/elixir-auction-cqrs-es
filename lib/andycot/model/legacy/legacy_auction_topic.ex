defmodule Andycot.LegacyAuctionTopic do
  use Ecto.Schema

  @primary_key {:auction_id, :id, autogenerate: false}
  
  schema "auctions_auction_topic" do
    field :topic_id,        :integer
    field :is_main,         :boolean
    field :display_order,   :integer
  end
end
