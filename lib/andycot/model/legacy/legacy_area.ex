defmodule Andycot.LegacyArea do
  use Ecto.Schema

  schema "auctions_area" do
    field :family_id, :integer
    field :code, :string
    field :is_disabled,	:boolean
    field :can_sell, :boolean
    field :hierarchy, :integer
    field :active_auction, :integer
    field :root_id, :integer
    field :lft, :integer
    field :rgt, :integer
    field :level, :integer
    field :sas_breadcrumb_at, Ecto.DateTime

    has_many :area_translations, Andycot.LegacyAreaTranslation, foreign_key: :id
  end
end
