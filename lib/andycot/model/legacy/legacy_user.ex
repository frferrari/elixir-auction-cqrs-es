defmodule Andycot.LegacyUser do
  use Ecto.Schema

  schema "sf_guard_user" do
    field :username, :string
    field :algorithm, :string
    field :salt, :string
    field :password, :string
    field :is_active, :boolean
    field :is_super_admin, :boolean
    field :last_login, Ecto.DateTime
    field :currency_id, :integer
    field :nickname, :string
    field :last_name, :string
    field :first_name, :string
    field :avatar, :string
    field :date_of_birth, Ecto.DateTime
    field :phone, :string
    field :mobile, :string
    field :fax, :string
    field :is_newsletter, :boolean
    field :culture, :string
    field :token, :string
    field :description, :string
    field :is_locked, :boolean
    field :holiday_start, Ecto.DateTime
    field :holiday_end, Ecto.DateTime
    field :sending_country, :string
    field :unsubscribe_at, Ecto.DateTime
    field :invoice_name, :string
    field :invoice_address1, :string
    field :invoice_address2, :string
    field :invoice_zip_code, :string
    field :invoice_city, :string
    field :invoice_country, :string
    field :vat_intra, :string
    field :slug, :string
    field :is_receive_renewals, :boolean
    field :holiday_hide_id, :integer
    field :listed_time_id, :integer
    field :bidding_up, :decimal
    field :autotitle_id, :integer
    
    timestamps([{:inserted_at, :created_at}])
  end
end
