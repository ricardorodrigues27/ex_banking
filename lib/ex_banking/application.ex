defmodule ExBanking.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    supervisor_config = [
      strategy: :one_for_one,
      max_seconds: 30,
      name: ExBanking.UserWorkersSupervisor
    ]

    children = [
      {Registry, name: ExBanking.UserBucketRegistry, keys: :unique},
      {Registry, name: ExBanking.UserWorkerRegistry, keys: :unique},
      {DynamicSupervisor, supervisor_config}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExBanking.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
