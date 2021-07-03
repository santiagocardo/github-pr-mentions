defmodule GithubPrMentionsWeb.ShowMentions do
  use GithubPrMentionsWeb, :live_component

  @impl true
  def mount(socket) do
    {:ok, assign(socket, mentions: []), temporary_assigns: [mentions: []]}
  end

  @impl true
  def render(assigns) do
    ~L"""
    <article id="pr-view-<%= @id %>">
      <div class="row">
        <h1>PR Number: <%= @id %></h1>
      </div>

      <div class="row">
        <table>
          <thead>
            <tr>
              <th>
                Date
              </th>
              <th>
                Mention
              </th>
              <th>
                URL
              </th>
            </tr>
          </thead>
          <tbody phx-update="append" id="pr-<%= @id %>-mentions">
            <%= for mention <- @mentions do %>
              <tr id="<%= mention.id %>">
                <th>
                  <span>
                    <%= mention.updated_at %>
                  </span>
                </th>
                <td>
                  <%= raw mention.body %>
                </td>
                <td>
                  <a href="<%= mention.url %>" target="_blank">
                    View comment on GitHub
                  </a>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </article>
    """
  end
end
