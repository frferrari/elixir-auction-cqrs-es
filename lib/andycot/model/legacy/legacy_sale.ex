defmodule Andycot.LegacySale do
  use Ecto.Schema

  schema "auctions_sale" do
    field :auction_id, :integer
    field :user_id, :integer
    field :deal_id, :integer
    field :quantity, :integer
    field :unit_price, :decimal
    field :site_unit_price, :decimal
    field :is_sold, :boolean
    field :cancel, :boolean
    field :has_litigation, :boolean
    field :is_committed, :boolean
  end
end
