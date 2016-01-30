defmodule Andycot.LegacyAreaTranslation do
  use Ecto.Schema

  schema "auctions_area_translation" do
    field :name, :string
    field :rank, :integer
    field :lang, :string
    field :slug, :string
    field :short_name, :string
    field :sas_breadcrumb, :string
  end
end
