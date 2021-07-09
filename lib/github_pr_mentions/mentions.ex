defmodule GithubPrMentions.Mentions do
  use GenServer

  alias GithubPrMentions.GitHub

  @refresh_interval :timer.seconds(60)
  @task_supervisor GithubPrMentions.TaskSupervisor
  @pubsub GithubPrMentions.PubSub
  @topic "mentions"

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

  def subscribe(content_id) do
    Phoenix.PubSub.subscribe(@pubsub, topic(content_id))
  end

  def init(_opts) do
    state = %{
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
    %{base_url: base_url, token: token, prs_curr_page: prs_curr_page} = state

    pr_numbers =
      Task.Supervisor.async(
        @task_supervisor,
        GitHub,
        :fetch_pulls,
        [base_url, token, page],
        shutdown: :brutal_kill
      )
      |> Task.await()

    unless pr_numbers == [] do
      Enum.each(pr_numbers, &GenServer.cast(via(state.id), {:fetch_mentions, &1, 1}))

      GenServer.cast(via(state.id), {:fetch_pulls, page + 1})
    end

    prs_curr_page = Enum.into(pr_numbers, prs_curr_page, &{&1, 1})

    state = Map.put(state, :prs_curr_page, prs_curr_page)

    {:noreply, state}
  end

  def handle_cast({:fetch_mentions, pr_number, page}, state) do
    %{base_url: base_url, token: token, username: username} = state

    mentions =
      Task.Supervisor.async(
        @task_supervisor,
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

      GenServer.cast(via(state.id), {:fetch_mentions, pr_number, page + 1})

      {:noreply, put_in(state, [:prs_curr_page, pr_number], page)}
    end
  end

  def handle_info(:refresh_mentions, state) do
    for pr_number <- Map.keys(state.prs_curr_page) do
      GenServer.cast(
        via(state.id),
        {:fetch_mentions, pr_number, get_in(state, [:prs_curr_page, pr_number])}
      )
    end

    {:noreply, schedule_refresh(state)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:stop, :normal, state}
  end

  defp schedule_refresh(state) do
    pid = GenServer.whereis(via(state.id))

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

  def via(lv_pid) do
    {:via, Registry, {GithubPrMentions.Registry.Mentions, lv_pid}}
  end
end
