defmodule GithubPrMentions.Mentions do
  use GenServer

  alias GithubPrMentions.GitHub

  @refresh_interval :timer.seconds(30)
  @pubsub GithubPrMentions.PubSub
  @topic "mentions"

  def subscribe(content_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(content_id))
  end

  def get_mentions(repo_url, username, token) do
    send(__MODULE__, {:set_initial_state, repo_url, username, token})
    send(__MODULE__, {:fetch_pulls, 1})

    :ok
  end

  def clean() do
    Task.Supervisor.children(GithubPrMentions.TaskSupervisor)
    |> Enum.each(&Task.Supervisor.terminate_child(GithubPrMentions.TaskSupervisor, &1))
  end

  def start_link(opts) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def init(opts) do
    state = %{
      interval: opts[:refresh_interval] || @refresh_interval,
      timer: nil,
      prs_curr_page: %{},
      base_url: nil,
      username: nil,
      token: nil
    }

    {:ok, schedule_refresh(state)}
  end

  def handle_info({:set_initial_state, repo_url, username, token}, state) do
    initial_state = %{
      base_url: GitHub.get_base_url(repo_url),
      username: username,
      token: token
    }

    {:noreply, Map.merge(state, initial_state)}
  end

  def handle_info({:fetch_pulls, page}, state) do
    %{base_url: base_url, token: token, prs_curr_page: prs_curr_page} = state

    pr_numbers =
      Task.Supervisor.async(
        GithubPrMentions.TaskSupervisor,
        GitHub,
        :fetch_pulls,
        [base_url, token, page],
        shutdown: :brutal_kill
      )
      |> Task.await()

    unless pr_numbers == [] do
      send(__MODULE__, {:fetch_pulls, page + 1})

      Enum.each(pr_numbers, &send(__MODULE__, {:fetch_mentions, &1, 1}))
    end

    prs_curr_page = Enum.into(pr_numbers, prs_curr_page, &{&1, 1})

    state = Map.put(state, :prs_curr_page, prs_curr_page)

    {:noreply, state}
  end

  def handle_info({:fetch_mentions, pr_number, page}, state) do
    %{base_url: base_url, token: token, username: username} = state

    mentions =
      Task.Supervisor.async(
        GithubPrMentions.TaskSupervisor,
        GitHub,
        :fetch_mentions,
        [base_url, pr_number, token, username, page],
        shutdown: :brutal_kill
      )
      |> Task.await()

    if mentions == [] do
      {:noreply, state}
    else
      broadcast_new_mentions({pr_number, mentions, username})

      send(__MODULE__, {:fetch_mentions, pr_number, page + 1})

      {:noreply, put_in(state, [:prs_curr_page, pr_number], page)}
    end
  end

  def handle_info(:refresh_mentions, state) do
    for pr_number <- Map.keys(state.prs_curr_page) do
      send(__MODULE__, {
        :fetch_mentions,
        pr_number,
        get_in(state, [:prs_curr_page, pr_number])
      })
    end

    {:noreply, schedule_refresh(state)}
  end

  defp schedule_refresh(state) do
    pid = GenServer.whereis(__MODULE__)

    %{state | timer: Process.send_after(pid, :refresh_mentions, state.interval)}
  end

  defp topic(content_id), do: "#{@topic}:#{content_id}"

  defp broadcast_new_mentions({pr_number, mentions, username}) do
    Phoenix.PubSub.broadcast_from!(
      @pubsub,
      self(),
      topic("lobby"),
      {__MODULE__, :new_mentions, {pr_number, mentions, username}}
    )
  end
end
