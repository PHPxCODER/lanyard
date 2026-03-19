defmodule Lanyard.DiscordBot.InteractionHandler do
  import Bitwise

  alias Lanyard.DiscordBot.DiscordApi
  alias Lanyard.KV.Interface, as: KV
  alias Lanyard.Connectivity.Redis

  @administrator 0x8
  @manage_guild 0x20

  def handle_interaction(data) do
    user_id = get_user_id(data)
    command = data["data"]["name"]
    options = parse_options(data)
    is_admin = admin?(data)

    case command do
      "kv" -> handle_kv(user_id, data)
      "get" -> handle_get(user_id, options, is_admin, data)
      "set" -> handle_set(user_id, options, is_admin, data)
      "del" -> handle_del(user_id, options, is_admin, data)
      "apikey" -> handle_apikey(user_id, data)
      "stats" -> handle_stats(user_id, data)
      _ -> :ok
    end
  end

  defp handle_kv(user_id, data) do
    kv = Redis.hgetall("lanyard_kv:#{user_id}")
    keys = Map.keys(kv)

    msg =
      if Enum.empty?(keys) do
        "You have no KV keys set."
      else
        "Your KV keys: `#{Enum.join(keys, "`, `")}`"
      end

    respond(data, msg)
  end

  defp handle_get(user_id, options, is_admin, data) do
    key = options["key"]
    target_id = resolve_target(user_id, options, is_admin)

    case KV.get(target_id, key) do
      {:ok, v} -> respond(data, "Key `#{key}`: ```#{String.replace(v, "`", "`\u200b")}```")
      {:error, msg} -> respond(data, msg)
    end
  end

  defp handle_set(user_id, options, is_admin, data) do
    key = options["key"]
    value = options["value"]
    target_id = resolve_target(user_id, options, is_admin)

    case KV.set(target_id, key, value) do
      {:ok, _} -> respond(data, "<a:tickmark_cym:1000427958168719390> `#{key}` was set.")
      {:error, reason} -> respond(data, ":x: #{reason}")
    end
  end

  defp handle_del(user_id, options, is_admin, data) do
    key = options["key"]
    target_id = resolve_target(user_id, options, is_admin)
    KV.del(target_id, key)
    respond(data, "<a:tickmark_cym:1000427958168719390> Deleted key `#{key}`.")
  end

  defp handle_apikey(user_id, data) do
    key = get_or_generate_key(user_id)
    respond(data, "Your Lanyard API key (only you can see this):\n||#{key}||", ephemeral: true)
  end

  defp handle_stats(user_id, data) do
    analytics = Redis.hgetall("lanyard_analytics:#{user_id}")
    kv = Redis.hgetall("lanyard_kv:#{user_id}")

    presence_updates = Map.get(analytics, "presence_updates", "0")
    spotify_plays = Map.get(analytics, "spotify_plays", "0")
    kv_count = map_size(kv)

    respond(data, """
    <a:tickmark_cym:1000427958168719390> **Your Lanyard Stats**
    > Presence Updates Tracked: **#{presence_updates}**
    > Spotify Plays Tracked: **#{spotify_plays}**
    > KV Keys Stored: **#{kv_count}**
    """)
  end

  defp resolve_target(user_id, options, is_admin) do
    if is_admin, do: Map.get(options, "user", user_id), else: user_id
  end

  defp respond(data, content, opts \\ []) do
    sanitized = String.replace(content, "@", "@\u200b")
    ephemeral = Keyword.get(opts, :ephemeral, false)

    DiscordApi.respond_to_interaction(
      Integer.to_string(data["id"]),
      data["token"],
      sanitized,
      ephemeral
    )
  end

  defp get_user_id(data) do
    case data do
      %{"member" => %{"user" => %{"id" => id}}} -> Integer.to_string(id)
      %{"user" => %{"id" => id}} -> Integer.to_string(id)
      _ -> nil
    end
  end

  defp parse_options(data) do
    options = get_in(data, ["data", "options"]) || []

    Enum.reduce(options, %{}, fn opt, acc ->
      Map.put(acc, opt["name"], coerce_value(opt["value"]))
    end)
  end

  defp coerce_value(v) when is_integer(v), do: Integer.to_string(v)
  defp coerce_value(v), do: v

  defp admin?(data) do
    case get_in(data, ["member", "permissions"]) do
      perms when is_binary(perms) ->
        perm_int = String.to_integer(perms)
        (perm_int &&& @administrator) != 0 or (perm_int &&& @manage_guild) != 0

      perms when is_integer(perms) ->
        (perms &&& @administrator) != 0 or (perms &&& @manage_guild) != 0

      _ ->
        false
    end
  end

  defp get_or_generate_key(user_id) do
    case Redis.get("user_api_key:#{user_id}") do
      nil ->
        key = Lanyard.DiscordBot.Commands.ApiKey.generate_api_key()
        Redis.set("user_api_key:#{user_id}", key)
        Redis.set("api_key:#{key}", user_id)
        key

      existing ->
        existing
    end
  end
end
