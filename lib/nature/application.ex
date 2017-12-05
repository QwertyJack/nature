defmodule Nature.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # Starts a worker by calling: Nature.Worker.start_link(arg)
      # {Nature.Worker, arg},
      #supervisor(Nature.Repo, []),
      Nature.Repo,
    ]

    # record cookie
    :ets.new :nature, [:public, :ordered_set, :named_table]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Nature.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
