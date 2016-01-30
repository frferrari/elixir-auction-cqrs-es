defmodule Andycot.LegacyFamily do
  use Ecto.Schema

  schema "auctions_family" do
    field :is_active, :boolean
    field :number_option_listing, :integer
    field :area_hierarchy, :integer
    field :position, :integer

    has_many :types, Andycot.LegacyType, foreign_key: :id, references: :id
  end
end
