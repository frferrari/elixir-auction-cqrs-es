defmodule Andycot.LegacyType do
  use Ecto.Schema

  schema "auctions_type" do
    field :filename, :string
    field :active_auction, :integer
    field :is_referencial, :boolean
    field :with_matching, :boolean
    field :with_crop, :boolean
    field :with_editor, :boolean
    field :send_to_ltu, :boolean
    field :type_position, :integer
    field :quote_template_type, :integer
    field :moeye_can_browse, :boolean
    field :first_option_id, :integer

    has_many :option_types, Andycot.LegacyOptionType, foreign_key: :type_id

    belongs_to :family, Andycot.LegacyFamily, foreign_key: :family_id, references: :id
  end
end
