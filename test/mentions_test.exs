defmodule MentionsTest do
  use ExUnit.Case

  alias GithubPrMentions.Mentions

  test "start Github Mentions GenServer" do
    repo_url = "https://github.com/phoenixframework/phoenix"
    username = "josevalim"
    token = "test token"

    assert :ok = Mentions.clean()
    assert :ok = Mentions.get_mentions(repo_url, username, token)
  end
end
