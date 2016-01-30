defmodule Andycot.LegacyOption do
  use Ecto.Schema

  schema "auctions_option" do
    field :family_id, :integer
    field :format, :integer
    field :is_auction, :boolean
    field :position, :integer

    has_many :option_translations, Andycot.LegacyOptionTranslation
    # has_many :option_types, Andycot.LegacyOption, foreign_key: :option_id

    has_one :option_type, Andycot.LegacyOptionType, foreign_key: :option_id
  end
end
