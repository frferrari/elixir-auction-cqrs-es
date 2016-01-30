defmodule Andycot.LegacyOptionValueTranslation do
  use Ecto.Schema

  schema "auctions_option_value_translation" do
    field :name, :string
    field :lang, :string
    field :slug, :string

    belongs_to :option_value, Andycot.LegacyOptionValue
  end
end
