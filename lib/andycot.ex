defmodule Andycot do
  use Application
  require Logger

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      # Start the endpoint when the application starts
      supervisor(Andycot.Endpoint, []),
      worker(Andycot.Repo, []),
      worker(Andycot.LegacyRepo, []),
      worker(Andycot.Service.UserEmailRegistry, []),
      worker(Andycot.Service.UserIdRegistry, []),
      worker(AuctionCounterService, [1]),
      worker(Andycot.Service.UserCounter, [1]),
      supervisor(Andycot.AuctionSupervisor, []),
      supervisor(Andycot.UserSupervisor, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Andycot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Andycot.Endpoint.config_change(changed, removed)
    :ok
  end
end
