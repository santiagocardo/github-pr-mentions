defmodule GithubPrMentionsWeb.PageLive do
  use GithubPrMentionsWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    oauth_github_url = ElixirAuthGithub.login_url(%{scopes: ["user:email"]})
    current_user = session["current_user"] || nil

    {:ok, assign(socket, oauth_github_url: oauth_github_url, current_user: current_user)}
  end

  @impl true
  def handle_event("search", params, socket) do
    {:noreply, push_redirect(socket, to: Routes.mentions_path(socket, :index, params))}
  end
end
