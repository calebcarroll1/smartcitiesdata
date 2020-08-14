defmodule DiscoveryStreams.Stream do
  @moduledoc """
  Process to wrap the processes that push messages through `discovery_streams`.
  This `GenServer` links processes for reading messages from a `Source.t()` impl
  and caching if the `Load` is configured to do so.
  """

  use GenServer, shutdown: 30_000
  use Annotated.Retry
  use Properties, otp_app: :discovery_streams
  require Logger
  # import Definition, only: [identifier: 1]

  # alias Broadcast.ViewState

  @max_retries get_config_value(:max_retries, default: 50)

  # @type init_opts :: [
  #         load: Load.t()
  #       ]

  def start_link(init_opts) do
    server_opts = Keyword.take(init_opts, [:name])
    GenServer.start_link(__MODULE__, init_opts, server_opts)
  end

  @impl GenServer
  def init(init_opts) do
    Process.flag(:trap_exit, true)
    Logger.debug(fn -> "#{__MODULE__}: init with #{inspect(init_opts)}" end)

    state = %{
      load: Keyword.fetch!(init_opts, :load)
    }

    {:ok, state, {:continue, :init}}
  end

  @impl GenServer
  def handle_continue(:init, state) do
    with {:ok, cache_pid} <- start_cache(state.load),
         {:ok, source_pid} <- start_source(state.load) do
      new_state =
        state
        |> Map.put(:cache_pid, cache_pid)
        |> Map.put(:source_pid, source_pid)

      {:noreply, new_state}
    else
      {:error, reason} ->
        {:stop, reason, state}
    end
  end

  @retry with: exponential_backoff(100) |> take(@max_retries)
  defp start_cache(load) do
    # TODO: Implement me
    # cache_name = Broadcast.Cache.Registry.via(load.destination.name)
    # Broadcast.Cache.start_link(name: cache_name, load: load)
  end

  @retry with: exponential_backoff(100) |> take(@max_retries)
  defp start_source(load) do
    context =
      Source.Context.new!(
        handler: Broadcast.Stream.SourceHandler,
        app_name: :discovery_streams,
        dataset_id: load.dataset_id,
        assigns: %{
          load: load,
          cache: Broadcast.Cache.Registry.via(load.destination.name),
          kafka: %{
            offset_reset_policy: :reset_to_latest
          }
        }
      )

    Source.start_link(load.source, context)
  end

  @impl GenServer
  def terminate(reason, state) do
    if Map.has_key?(state, :cache_pid) do
      Map.get(state, :cache_pid) |> kill(reason)
    end

    if Map.has_key?(state, :source) do
      pid = Map.get(state, :source_pid)
      Source.stop(state.load.source, pid)
    end

    reason
  end

  defp kill(pid, reason) do
    Process.exit(pid, reason)

    receive do
      {:EXIT, ^pid, _} ->
        :ok
    after
      20_000 -> :ok
    end
  end
end
