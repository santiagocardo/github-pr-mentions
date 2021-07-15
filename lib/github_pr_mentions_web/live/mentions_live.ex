defmodule GithubPrMentionsWeb.MentionsLive do
  use GithubPrMentionsWeb, :live_view

  alias GithubPrMentions.Mentions

  @impl true
  def mount(%{"repo" => repo, "username" => username}, %{"current_user" => current_user}, socket) do
    Mentions.get_mentions(repo, username, current_user.access_token, self())

    {:ok,
     socket
     |> assign(prs: [], username: username)
     |> put_flash(:info, "Searching mentions..."), temporary_assigns: [prs: []]}
  end

  @impl true
  def handle_info({:new_mentions, pr_number, mentions}, socket) do
    send_update(GithubPrMentionsWeb.ShowMentions, id: pr_number, mentions: mentions)

    {:noreply,
     socket
     |> assign(:prs, [pr_number])
     |> put_flash(:info, "Looking for more mentions...")}
  end
end
