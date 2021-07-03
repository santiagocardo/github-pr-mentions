defmodule GithubPrMentionsWeb.Auth do
  import Plug.Conn
  import Phoenix.Controller

  alias GithubPrMentionsWeb.Router.Helpers, as: Routes

  def init(opts), do: opts

  def call(conn, _opts) do
    user = get_session(conn, :current_user)

    assign(conn, :current_user, user)
  end

  def logout(conn) do
    configure_session(conn, drop: true)
  end

  def authenticate_user(conn, _opts) do
    if conn.assigns.current_user do
      conn
    else
      conn
      |> put_flash(:error, "You must be logged in to access this page")
      |> redirect(to: Routes.page_path(conn, :index))
      |> halt()
    end
  end
end
