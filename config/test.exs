use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :andycot, Andycot.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :error

# Configure your database  
config :andycot, Andycot.LegacyRepo,
  adapter: Ecto.Adapters.MySQL,
  database: "andycot_bdd",
  username: "root",
  password: "2c3x27z",
  pool: Ecto.Adapters.SQL.Sandbox

config :andycot, Andycot.Repo,
  adapter: Mongo.Ecto,
  database: "andycot",
  username: "eventide",
  password: "pastaga",
  hostname: "localhost"
