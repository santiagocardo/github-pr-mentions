defmodule GithubPrMentions.GitHub do
  def fetch_pulls(base_url, token, page \\ 1) do
    base_url
    |> pulls_url(page)
    |> fetch(token)
    |> map_pulls()
  end

  def fetch_comments({pr_number, page}, base_url, token) do
    comments_url(base_url, pr_number, page)
    |> fetch(token)
    |> map_comments(pr_number, page)
  end

  def get_base_url(repo_url) do
    [_, owner, repo] =
      repo_url
      |> String.split("github.com")
      |> Enum.at(1)
      |> String.split("/")

    "https://api.github.com/repos/#{owner}/#{repo}"
  end

  defp fetch(url, token) do
    url
    |> HTTPoison.get(Authorization: "token #{token}", accept: "application/vnd.github.v3+json")
    |> handle_response()
  end

  defp pulls_url(base_url, page) do
    base_url <> "/pulls?page=#{page}"
  end

  defp comments_url(base_url, number, page) do
    base_url <> "/issues/#{number}/comments?page=#{page}"
  end

  defp handle_response({:ok, %{status_code: status_code, body: body}}) do
    {
      status_code |> check_for_error(),
      body |> Poison.Parser.parse!(%{})
    }
  end

  defp handle_response({:error, res}), do: res

  defp check_for_error(200), do: :ok
  defp check_for_error(_), do: :error

  defp map_pulls({:ok, pulls}) do
    Enum.map(pulls, & &1["number"])
  end

  defp map_pulls(_res), do: []

  defp map_comments({:ok, comments}, pr_number, page), do: {pr_number, comments, page}
  defp map_comments(_res, pr_number, page), do: {pr_number, [], page}
end
