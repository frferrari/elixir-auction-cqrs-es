defmodule Andycot.LegacyAuction do
  use Ecto.Schema

  schema "auctions_auction" do
    field :user_id, :integer
    field :area_id, :integer
    field :type_id, :integer
    field :year, :integer
    field :matched_id, :integer
    field :listed_time_id, :integer
    field :sale_type_id, :integer
    field :description, :string
    field :starting_price, :decimal
    field :current_price, :decimal
    field :bidding_up, :decimal
    field :reserve_price, :decimal
    field :stock, :integer
    field :starting_date, Ecto.DateTime
    field :starting_date_time, :integer
    field :end_date, Ecto.DateTime
    field :end_date_time, :integer
    field :end_mail, :boolean
    field :pending_date, Ecto.DateTime
    field :automatic_renewal, :boolean
    field :renewal_count, :integer
    field :count_view, :integer
    field :is_closed, :boolean
    field :buyer_id, :integer
    field :currency_code, :string
    field :subtitle, :string
    field :current_highest_bidder, :integer
    field :title, :string
    field :slug, :string
    timestamps([{:inserted_at, :created_at}])

    has_many :topics, Andycot.LegacyAuctionTopic, foreign_key: :auction_id
    has_many :bids, Andycot.LegacyBid, foreign_key: :auction_id
    has_many :auction_option_values, Andycot.LegacyAuctionOptionValue, foreign_key: :auction_id

    has_many :option_values, through: [:auction_option_values, :option_value]

    has_many :sell_options, Andycot.LegacyAuctionSellOption, foreign_key: :auction_id
    
    has_many :sales, Andycot.LegacySale, foreign_key: :auction_id

    has_one :area, Andycot.LegacyArea, references: :area_id, foreign_key: :id
  end
end
