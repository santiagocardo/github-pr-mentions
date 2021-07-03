defmodule GithubPrMentionsWeb.MentionsLiveTest do
  use GithubPrMentionsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "with not logged-in user" do
    test "requires user authentication on mentions page", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/"}}} = live(conn, "/mentions")
    end
  end

  describe "with a logged-in user" do
    setup %{conn: conn} do
      user = %{login: "santiagocardo80", access_token: "test token"}

      conn =
        assign(conn, :current_user, user)
        |> Plug.Test.init_test_session(%{})
        |> put_session(:current_user, user)

      {:ok, conn: conn, user: user}
    end

    test "disconnected and connected render", %{conn: conn} do
      repo_url = "https://github.com/phoenixframework/phoenix"
      username = "josevalim"
      url = "/mentions?repo=#{repo_url}&username=#{username}"

      {:ok, page_live, disconnected_html} = live(conn, url)

      assert disconnected_html =~ username
      assert render(page_live) =~ username
    end
  end
end
