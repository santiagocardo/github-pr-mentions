defmodule GithubPrMentions.Mentions do
  use GenServer

  alias GithubPrMentions.GitHub

  @refresh_interval :timer.seconds(60)
  @task_supervisor GithubPrMentions.TaskSupervisor

  def child_spec(lv_pid) do
    %{
      id: {__MODULE__, lv_pid},
      start: {__MODULE__, :start_link, [lv_pid]},
      restart: :temporary
    }
  end

  def start_link(lv_pid) do
    GenServer.start_link(
      __MODULE__,
      lv_pid,
      name: via(lv_pid)
    )
  end

  def get_mentions(repo_url, username, token, lv_pid) do
    DynamicSupervisor.start_child(
      GithubPrMentions.Supervisor.Mentions,
      {__MODULE__, lv_pid}
    )

    GenServer.cast(via(lv_pid), {:set_initial_state, repo_url, username, token, lv_pid})
    GenServer.cast(via(lv_pid), {:fetch_pulls, 1})
  end

  def via(lv_pid) do
    {:via, Registry, {GithubPrMentions.Registry.Mentions, lv_pid}}
  end

  def init(_opts) do
    state = %{
      id: nil,
      interval: @refresh_interval,
      timer: nil,
      prs_curr_page: %{},
      base_url: nil,
      username: nil,
      token: nil
    }

    {:ok, state}
  end

  def handle_cast({:set_initial_state, repo_url, username, token, lv_pid}, state) do
    Process.monitor(lv_pid)

    initial_state = %{
      base_url: GitHub.get_base_url(repo_url),
      username: username,
      token: token,
      id: lv_pid
    }

    state = Map.merge(state, initial_state)

    {:noreply, schedule_refresh(state)}
  end

  def handle_cast({:fetch_pulls, page}, state) do
    %{base_url: base_url, token: token} = state

    pr_numbers = fetch_pulls(base_url, token, page)

    unless pr_numbers == [] do
      mentions_to_fetch = Enum.map(pr_numbers, &{&1, 1})

      GenServer.cast(via(state.id), {:fetch_mentions, mentions_to_fetch})
      GenServer.cast(via(state.id), {:fetch_pulls, page + 1})
    end

    state = Enum.reduce(pr_numbers, state, &put_in(&2, [:prs_curr_page, &1], 1))

    {:noreply, state}
  end

  def handle_cast({:fetch_mentions, prs_data}, state) do
    %{base_url: base_url, token: token, username: username} = state

    mentions = fetch_mentions(prs_data, base_url, token, username)

    if mentions == [] do
      {:noreply, state}
    else
      mentions_to_fetch =
        Enum.map(mentions, fn {pr_number, mentions, page} ->
          send(state.id, {:new_mentions, pr_number, mentions})

          {pr_number, page + 1}
        end)

      GenServer.cast(via(state.id), {:fetch_mentions, mentions_to_fetch})

      state =
        Enum.reduce(mentions, state, fn {pr_number, _mentions, page}, acc ->
          put_in(acc, [:prs_curr_page, pr_number], page)
        end)

      {:noreply, state}
    end
  end

  def handle_info(:refresh_mentions, state) do
    GenServer.cast(via(state.id), {:fetch_mentions, Map.to_list(state.prs_curr_page)})

    {:noreply, schedule_refresh(state)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:stop, :normal, state}
  end

  defp schedule_refresh(state) do
    pid = GenServer.whereis(via(state.id))

    %{state | timer: Process.send_after(pid, :refresh_mentions, state.interval)}
  end

  defp fetch_pulls(base_url, token, page) do
    Task.Supervisor.async(
      @task_supervisor,
      GitHub,
      :fetch_pulls,
      [base_url, token, page],
      shutdown: :brutal_kill
    )
    |> Task.await()
  end

  defp fetch_mentions(prs_data, base_url, token, username) do
    Task.Supervisor.async_stream(
      @task_supervisor,
      prs_data,
      GitHub,
      :fetch_comments,
      [base_url, token],
      shutdown: :brutal_kill
    )
    |> Enum.reduce([], &mentions_reducer(&1, &2, username))
  end

  defp mentions_reducer({:ok, response}, acc, username) do
    case filter_comments(response, username) do
      {_pr_number, [], _page} -> acc
      result -> [result | acc]
    end
  end

  defp filter_comments({pr_number, comments, page}, username) do
    mentions =
      comments
      |> Enum.filter(&String.contains?(&1["body"], username))
      |> Enum.map(
        &%{
          id: &1["id"],
          body: &1["body"],
          url: &1["html_url"],
          updated_at: &1["updated_at"]
        }
      )

    {pr_number, mentions, page}
  end
end
