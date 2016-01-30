defmodule Andycot.LegacyOptionType do
  use Ecto.Schema

  schema "auctions_option_type" do
    field :key_group, :string
    field :position, :integer
    field :default_value, :string
    field :match_return_position, :integer
    field :is_picture, :boolean
    field :quote_level, :integer

    belongs_to :option, Andycot.LegacyOption, foreign_key: :option_id, references: :id
    belongs_to :type, Andycot.LegacyType, foreign_key: :type_id, references: :id
  end
end
