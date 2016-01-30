use Mix.Config

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we use it
# with brunch.io to recompile .js and .css sources.
config :andycot, Andycot.Endpoint,
  http: [port: 4000],
  debug_errors: true,
  code_reloader: true,
  cache_static_lookup: false,
  check_origin: false,
  watchers: [node: ["node_modules/brunch/bin/brunch", "watch", "--stdin"]]

# Watch static and templates for browser reloading.
config :andycot, Andycot.Endpoint,
  live_reload: [
    patterns: [
      ~r{priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$},
      ~r{web/views/.*(ex)$},
      ~r{web/templates/.*(eex)$}
    ]
  ]

# Do not include metadata nor timestamps in development logs
config :logger, :console, level: :info, format: "$date $time [$level] $message $metadata\n", metadata: [:module]

# Set a higher stacktrace during development.
# Do not configure such in production as keeping
# and calculating stacktraces is usually expensive.
config :phoenix, :stacktrace_depth, 20

# Configure your database
config :andycot, Andycot.Repo,
  adapter: Mongo.Ecto,
  database: "andycot",
  username: "eventide",
  password: "pastaga",
  hostname: "localhost"
  
config :andycot, Andycot.LegacyRepo,
  adapter: Ecto.Adapters.MySQL,
  database: "andycot_bdd",
  username: "root",
  password: "2c3x27z"
