defmodule GithubPrMentionsWeb.MentionsLive do
  use GithubPrMentionsWeb, :live_view

  alias GithubPrMentions.Mentions

  @impl true
  def mount(%{"repo" => repo, "username" => username}, %{"current_user" => current_user}, socket) do
    Mentions.get_mentions(repo, username, current_user.access_token)

    if connected?(socket), do: Mentions.subscribe("lobby")

    Process.send_after(self(), :check_prs, 90_000)

    {:ok,
     socket
     |> assign(prs: [], username: username)
     |> put_flash(:info, "Searching mentions..."), temporary_assigns: [prs: []]}
  end

  @impl true
  def handle_info({Mentions, :new_mentions, {pr_number, mentions, username}}, socket) do
    if username == socket.assigns.username do
      send_update(GithubPrMentionsWeb.ShowMentions, id: pr_number, mentions: mentions)

      {:noreply,
       socket
       |> assign(:prs, [pr_number])
       |> put_flash(:info, "Looking for more mentions...")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:check_prs, socket) do
    if socket.assigns.prs == [] do
      {:noreply, put_flash(socket, :error, "No mentions found!")}
    else
      {:noreply, socket}
    end
  end
end
