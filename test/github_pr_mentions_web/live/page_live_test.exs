defmodule GithubPrMentionsWeb.PageLiveTest do
  use GithubPrMentionsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  describe "with not logged-in user" do
    test "disconnected and connected render", %{conn: conn} do
      {:ok, page_live, disconnected_html} = live(conn, "/")

      assert disconnected_html =~ "Sign in with GitHub"
      assert render(page_live) =~ "Sign in with GitHub"
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
      {:ok, page_live, disconnected_html} = live(conn, "/")

      search_btn = "<button type=\"submit\" phx-disable-with=\"Searching...\">Search</button>"

      assert disconnected_html =~ search_btn
      assert render(page_live) =~ search_btn
    end
  end
end
