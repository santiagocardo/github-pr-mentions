defmodule GithubPrMentions.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      GithubPrMentionsWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: GithubPrMentions.PubSub},
      # Start the Endpoint (http/https)
      GithubPrMentionsWeb.Endpoint,
      {Task.Supervisor, name: GithubPrMentions.TaskSupervisor},
      {Registry, [name: GithubPrMentions.Registry.Mentions, keys: :unique]},
      {DynamicSupervisor, [name: GithubPrMentions.Supervisor.Mentions, strategy: :one_for_one]},
      GithubPrMentions.Mentions
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GithubPrMentions.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    GithubPrMentionsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
