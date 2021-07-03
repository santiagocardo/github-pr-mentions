defmodule GithubPrMentionsWeb.MentionsLive do
  use GithubPrMentionsWeb, :live_view

  @impl true
  def mount(%{"username" => username}, _session, socket) do
    {:ok,
     socket
     |> assign(prs: [], username: username)
     |> put_flash(:info, "Searching mentions..."), temporary_assigns: [prs: []]}
  end
end
