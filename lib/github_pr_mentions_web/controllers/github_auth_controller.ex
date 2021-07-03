defmodule GithubPrMentionsWeb.GithubAuthController do
  use GithubPrMentionsWeb, :controller

  alias GithubPrMentionsWeb.Router.Helpers, as: Routes

  def index(conn, %{"code" => code}) do
    {:ok, profile} = ElixirAuthGithub.github_auth(code)

    conn
    |> put_flash(:info, "Successfully authenticated")
    |> put_session(:user_id, profile.id)
    |> put_session(:current_user, profile)
    |> configure_session(renew: true)
    |> redirect(to: Routes.page_path(conn, :index))
  end
end
