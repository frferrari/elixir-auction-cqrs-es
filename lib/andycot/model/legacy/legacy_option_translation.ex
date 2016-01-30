defmodule Andycot.LegacyOptionTranslation do
  use Ecto.Schema

  schema "auctions_option_translation" do
    field :name, :string
    field :lang, :string
    field :slug, :string

    belongs_to :option, Andycot.LegacyOption
  end
end
