defmodule Andycot.LegacyRepo do
	use Ecto.Repo, otp_app: :andycot, adapter: Ecto.Adapters.MySQL
end