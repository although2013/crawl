defmodule Crawl.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    # List all child processes to be supervised
    children = [
      # %{
      #   id: Crawl,
      #   start: {Crawl, :start_link, []}
      # }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Crawl.Supervisor]
    Supervisor.start_link(children, opts)
  end
end