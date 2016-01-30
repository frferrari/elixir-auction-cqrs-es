defmodule Andycot.LegacyOptionValue do
  use Ecto.Schema

  schema "auctions_option_value" do
    field :display_order,	:integer
    field :is_stock, :boolean

    has_many :option_value_translations, Andycot.LegacyOptionValueTranslation, foreign_key: :id, references: :id

    belongs_to :option, Andycot.LegacyOption, foreign_key: :option_id, references: :id
  end
end
