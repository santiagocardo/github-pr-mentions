# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :github_pr_mentions, GithubPrMentionsWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "jnoVXDbdQrADOr1LJO1Jw4apQpXPyO2Ttd/4gYTJCFbHy0kNP6pCacZGJ6Z2y7/D",
  render_errors: [view: GithubPrMentionsWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: GithubPrMentions.PubSub,
  live_view: [signing_salt: "xXT+IkHh"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
