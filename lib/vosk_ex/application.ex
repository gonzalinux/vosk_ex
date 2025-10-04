defmodule VoskEx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    # Log level is configured during NIF load (see VoskEx.load_nifs/0)
    # Users can change it at runtime with VoskEx.set_log_level/1

    children = [
      # Starts a worker by calling: VoskEx.Worker.start_link(arg)
      # {VoskEx.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: VoskEx.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
