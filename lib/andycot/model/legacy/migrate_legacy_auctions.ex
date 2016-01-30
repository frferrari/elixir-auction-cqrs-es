#
# curl -XGET localhost:9200/auctions/article/1
#
# curl -XPOST 'localhost:9200/auctions/article/1/_update' -d '{
# "script": { "id": "viewAuctionsAppendTopicId", "lang": "groovy" }, "params": { "new_topic_id": 1900 }
# }'
#

defmodule Andycot.MigrateLegacy.Auctions do
  @page_size 200

  import Ecto.Query
  import Ecto.Type

  import Andycot.Tools.Timestamp
  alias Andycot.AuctionSupervisor
  alias Andycot.Model.UserEvent

  #
  # mix compile --force
  # iex -S mix
  # Andycot.start()
  # c("lib/migrate_auctions.exs")
  # MigrateLegacyAuctions.migrate_all()
  #

  defp get_auctions_query() do
    from a in Andycot.LegacyAuction
  end

  defp get_auctions_query(limit, offset) do
    # from a in Andycot.LegacyAuction, select: a.id, limit: ^limit, offset: ^offset, order_by: [asc: :id], where: a.id == 228
    from a in Andycot.LegacyAuction, select: a.id, limit: ^limit, offset: ^offset, order_by: [asc: :id]
  end

  @doc "Get a count of the auctions in the legacy database"
  def get_auctions_count do
    (from c in get_auctions_query(), select: count(c.id)) |> Andycot.LegacyRepo.all
  end

  @doc "Get a list of auctions from the legacy database given a page number"
  def get_auctions(page_number) do
    offset = @page_size * (page_number - 1)

    auction_ids = get_auctions_query(@page_size, offset) |> Andycot.LegacyRepo.all

    query = from a in Andycot.LegacyAuction,
      left_join: b in assoc(a, :bids),
      left_join: u in assoc(b, :user),
      left_join: aov in assoc(a, :auction_option_values),
      left_join: ov in assoc(aov, :option_value),
      left_join: o in assoc(ov, :option),
      left_join: ot in Andycot.LegacyOptionType, on: ot.type_id == a.type_id and ot.option_id == o.id,
      select: a,
      where: a.id in ^auction_ids,
      preload: [:topics],
      preload: [:area],
      preload: [:sell_options],
      preload: [:sales],
      preload: [bids: {b, user: u}],
      preload: [auction_option_values: {aov, option_value: {ov, option: {o, option_type: ot}}}],
      order_by: [asc: :id]

    query |> Andycot.LegacyRepo.all 
  end

  @doc "Migrate all auctions from the legacy database to elasticsearch"
  def migrate_all(page_number \\ 1) do
    migrate_page(page_number, get_auctions(page_number))
  end

  defp migrate_page(_page_number, []) do
    IO.puts "Migration finished"
  end

  defp migrate_page(page_number, auctions) do
    IO.puts "Migrating auctions for page #{page_number}"

    for auction <- auctions do

      bids = auction.bids |> Enum.sort(&(&1.id <= &2.id)) |> Enum.map(fn(bid) -> %{
        bidder_name: bid.user.nickname, 
        bidder_id: bid.user_id, 
        value: bid.value, # |> Decimal.to_string(:normal), 
        max_value: bid.max_value, # |> Decimal.to_string(:normal), 
        is_auto: bid.is_auto, 
        is_visible: bid.is_visible, 
        created_at: bid.created_at |> Ecto.DateTime.to_erl |> Andycot.Tools.Timestamp.to_timestamp
      } end)

      options = auction.auction_option_values
        |> Enum.map(fn(aov) -> %{
          option_value_id: aov.option_value_id, 
          value: aov.value, 
          is_stock: aov.option_value.is_stock, 
          family_id: aov.option_value.option.family_id, 
          format: aov.option_value.option.format, 
          is_auction: aov.option_value.option.is_auction, 
          position: aov.option_value.option.position,
          option_type_key_group: aov.option_value.option.option_type.key_group,
          option_type_position: aov.option_value.option.option_type.position
        } end)

      reserve_price_option = auction.sell_options |> Enum.filter(&(&1.option_id == 1))
      reserve_price = if length(reserve_price_option) == 1 do
        reserve_price = auction.reserve_price |> Decimal.to_string(:normal)
      else
        reserve_price = nil
      end

      {starting_price, _} = auction.starting_price |> Decimal.to_string(:normal) |> Float.parse
      {bid_up, _} = auction.bidding_up |> decimal_to_string |> Float.parse

      create_command = %Andycot.Command.Auction.CreateAuction{
        auction_id: auction.id, 
        seller_id: auction.user_id,
        type_id: auction.type_id,
        title: auction.title,
        description: auction.description,
        year: auction.year,
        area_id: auction.area_id,
        topic_ids: auction.topics |> Enum.map(&(&1.topic_id)),
        matched_id: auction.matched_id,
        listed_time_id: auction.listed_time_id,
        sale_type_id: auction.sale_type_id,
        start_price: starting_price,
        bid_up: bid_up,
        reserve_price: reserve_price,
        stock: auction.stock,
        start_date_time: auction.starting_date_time, # auction.starting_date,
        end_date_time: auction.end_date_time, # auction.end_date,
        automatic_renewal: auction.automatic_renewal,
        currency: auction.currency_code,
        slug: auction.slug,
        options: options,
        created_at: auction.created_at |> Ecto.DateTime.to_erl |> Andycot.Tools.Timestamp.to_timestamp
      }

      if auction.sale_type_id == 1 or (auction.sale_type_id == 2 and auction.stock > 0) do
        
        # Create the auction
        create_command |> AuctionSupervisor.create_auction(:legacy)

        # Create the associated bids
        if (bids |> Enum.count) > 0 do
          for bid <- bids do
            {max_value, _} = bid.max_value |> Decimal.to_string(:normal) |> Float.parse

            bid_command = %Andycot.Command.Auction.PlaceBid{
              auction_id: auction.id,
              bidder_name: bid.bidder_name,
              bidder_id: bid.bidder_id,
              max_value: max_value,
              created_at: bid.created_at
            }

            bid_command |> AuctionSupervisor.place_bid(:legacy)
          end
        end

        # Generate a close_auction_event when an auction is closed
        if auction.is_closed do
          close_command = %Andycot.Command.Auction.CloseAuction{
            auction_id: auction.id,
            closed_by: UserEvent.get_closed_by_system,
            reason: "Generated during the migration phase",
            created_at: auction.end_date |> Ecto.DateTime.to_erl |> Andycot.Tools.Timestamp.to_timestamp
          }

          close_command |> AuctionSupervisor.close_auction(:legacy)
        end

      end

    end

    next_page_number = page_number + 1
    migrate_page(next_page_number, get_auctions(next_page_number))
  end

  # Function used to convert Decimal values to string and dealing with nil values
  defp decimal_to_string(value) do
    if value == nil do
      "0.10"
    else 
      value |> Decimal.to_string(:normal)
    end
  end

end
