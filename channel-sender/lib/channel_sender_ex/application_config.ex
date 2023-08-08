defmodule ChannelSenderEx.ApplicationConfig do
  @moduledoc false

  alias Vapor.Provider.File

  require Logger

  def load() do
    config_file = Application.get_env(:channel_sender_ex, :config_file)
    Logger.info("Loading configuration from #{inspect(config_file)}")

    # Vapor
    providers = [
      %File{
        path: config_file,
        bindings: [
          channel_sender_ex: "channel_sender_ex",
          logger: "logger"
        ]
      }
    ]

    try do
      case Vapor.load(providers) do
        {:error, err} ->
          Logger.error("Error loading configuration, #{inspect(err)}")
          setup_config(%{})
        {:ok, config} ->
          setup_config(config)
      end
    rescue
      e in Vapor.FileNotFoundError ->
        Logger.error("Error loading configuration, #{inspect(e)}")
        setup_config(%{})
    end


  end

  def setup_config(config) do

    Logger.configure(level: String.to_existing_atom(
      Map.get(fetch(config, :logger), "level", "info")
    ))

    Application.put_env(:channel_sender_ex, :no_start,
      Map.get(fetch(config, :channel_sender_ex), "no_start", false)
    )

    Application.put_env(:channel_sender_ex, :channel_shutdown_tolerance,
      Map.get(fetch(config, :channel_sender_ex), "channel_shutdown_tolerance", 10_000)
    )

    Application.put_env(:channel_sender_ex, :min_disconnection_tolerance,
      Map.get(fetch(config, :channel_sender_ex), "min_disconnection_tolerance", 50)
    )

    Application.put_env(:channel_sender_ex, :on_connected_channel_reply_timeout,
      Map.get(fetch(config, :channel_sender_ex), "on_connected_channel_reply_timeout", 2000)
    )

    Application.put_env(:channel_sender_ex, :accept_channel_reply_timeout,
      Map.get(fetch(config, :channel_sender_ex), "accept_channel_reply_timeout", 1000)
    )

    Application.put_env(:channel_sender_ex, :secret_base,
      {
        Map.get(fetch(config, :channel_sender_ex, "secret_generator"), "base",
          "aV4ZPOf7T7HX6GvbhwyBlDM8B9jfeiwi+9qkBnjXxUZXqAeTrehojWKHkV3U0kGc"),
        Map.get(fetch(config, :channel_sender_ex, "secret_generator"), "salt", "10293846571")
      }
    )

    Application.put_env(:channel_sender_ex, :max_age,
      Map.get(fetch(config, :channel_sender_ex, "secret_generator"), "max_age", 900)
    )

    Application.put_env(:channel_sender_ex, :socket_port,
      Map.get(fetch(config, :channel_sender_ex), "socket_port", 8082)
    )

    Application.put_env(:channel_sender_ex, :rest_port,
      Map.get(fetch(config, :channel_sender_ex), "rest_port", 8081)
    )

    Application.put_env(:channel_sender_ex, :initial_redelivery_time,
      Map.get(fetch(config, :channel_sender_ex), "initial_redelivery_time", 900)
    )

    Application.put_env(:channel_sender_ex, :socket_idle_timeout,
      Map.get(fetch(config, :channel_sender_ex), "socket_idle_timeout", 30_000)
    )

    Application.put_env(:channel_sender_ex, :topology, parse_libcluster_topology(config))

    if (config == %{}) do
      Logger.warn("No valid configuration found!!!, Loading pre-defined default values : #{inspect(Application.get_all_env(:channel_sender_ex))}")
    else
      Logger.info("Succesfully loaded configuration: #{inspect(inspect(Application.get_all_env(:channel_sender_ex)))}")
    end

    config
  end

  defp parse_libcluster_topology(config) do
    topology = get_in(config, [:channel_sender_ex, "topology"])
    case topology do
      nil ->
        Logger.warn("No libcluster topology defined!!! -> Using Default [Gossip]")
        [ strategy: Cluster.Strategy.Gossip ]
      _ ->
        [
          strategy: String.to_existing_atom(topology["strategy"]),
          config: parse_config_key(topology["config"])
        ]
    end
  end

  defp parse_config_key(cfg) do
    case cfg do
      nil ->
        []
      _ ->
        Enum.map(cfg, fn({key, value}) ->
          {String.to_atom(key), process_param(value)}
        end)
    end
  end

  defp process_param(param) when is_integer(param) do
    param
  end

  defp process_param(param) when is_binary(param) do
    case String.starts_with?(param, ":") do
      true ->
        String.to_atom(String.replace_leading(param, ":", ""))
      false ->
        param
    end
  end

  defp fetch(config, base) do
    case get_in(config, [base]) do
      nil ->
        %{}
      data ->
        data
    end
  end

  defp fetch(config, base, key) do
    case get_in(config, [base, key]) do
      nil ->
        %{}
      data ->
        data
    end
  end

end
