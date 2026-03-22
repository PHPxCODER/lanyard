defmodule Lanyard.DiscordBot.InteractionHandler do
  alias Lanyard.DiscordBot.DiscordApi
  alias Lanyard.DiscordBot.Permissions
  alias Lanyard.KV.Interface, as: KV
  alias Lanyard.Connectivity.Redis

  def handle_interaction(data) do
    case data["type"] do
      5 -> handle_modal_submit(data)
      _ -> handle_command(data)
    end
  end

  defp handle_command(data) do
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
      "help" -> handle_help(data)
      _ -> :ok
    end
  end

  defp handle_modal_submit(data) do
    custom_id = data["data"]["custom_id"]

    case custom_id do
      "set_kv:" <> target_id ->
        user_id = get_user_id(data)
        is_admin = admin?(data)

        if target_id != user_id and not is_admin do
          respond(data, ":x: You are not authorized to set KV for another user.", ephemeral: true)
        else
          components = get_in(data, ["data", "components"]) || []
          values = parse_modal_components(components)
          key = Map.get(values, "key")
          value = Map.get(values, "value")

          if is_binary(key) and is_binary(value) do
            set_and_respond(target_id, key, value, data)
          else
            respond(data, ":x: Invalid key or value.", ephemeral: true)
          end
        end

      _ ->
        :ok
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

    case resolve_target(user_id, options, is_admin) do
      {:ok, target_id} ->
        case KV.get(target_id, key) do
          {:ok, v} -> respond(data, "Key `#{key}`: ```#{String.replace(v, "`", "`\u200b")}```")
          {:error, msg} -> respond(data, msg)
        end

      {:error, :no_permission} ->
        respond(data, ":x: You do not have permission to access another user's KV.", ephemeral: true)
    end
  end

  defp handle_set(user_id, options, is_admin, data) do
    case resolve_target(user_id, options, is_admin) do
      {:error, :no_permission} ->
        respond(data, ":x: You do not have permission to modify another user's KV.", ephemeral: true)

      {:ok, target_id} ->
    # If key+value already provided (old cached command), skip the modal
    if Map.has_key?(options, "key") and Map.has_key?(options, "value") do
      key = options["key"]
      value = options["value"]

      set_and_respond(target_id, key, value, data)
    else
      modal = %{
        title: "Set KV Value",
        custom_id: "set_kv:#{target_id}",
        components: [
          %{
            type: 1,
            components: [
              %{
                type: 4,
                custom_id: "key",
                label: "Key",
                style: 1,
                required: true,
                min_length: 1,
                max_length: 255,
                placeholder: "e.g. spotify_url"
              }
            ]
          },
          %{
            type: 1,
            components: [
              %{
                type: 4,
                custom_id: "value",
                label: "Value",
                style: 2,
                required: true,
                min_length: 1,
                max_length: 4000,
                placeholder: "Enter value"
              }
            ]
          }
        ]
      }

      DiscordApi.respond_with_modal(
        Integer.to_string(data["id"]),
        data["token"],
        modal
      )
    end
    end
  end

  defp handle_del(user_id, options, is_admin, data) do
    key = options["key"]

    case resolve_target(user_id, options, is_admin) do
      {:ok, target_id} ->
        KV.del(target_id, key)
        respond(data, "<a:tickmark_cym:1000427958168719390> Deleted key `#{key}`.", ephemeral: true)

      {:error, :no_permission} ->
        respond(data, ":x: You do not have permission to delete another user's KV.", ephemeral: true)
    end
  end

  defp handle_help(data) do
    components = [
      %{
        type: 17,
        components: [
          %{type: 10, content: "## Lanyard Commands"},
          %{type: 14, divider: true, spacing: 1},
          %{type: 10, content: "**`/kv`**\nList all your KV keys."},
          %{type: 10, content: "**`/get` `key`**\nGet the value of a KV key."},
          %{type: 10, content: "**`/set`**\nSet a KV key via a form popup."},
          %{type: 10, content: "**`/del` `key`**\nDelete a KV key."},
          %{type: 10, content: "**`/apikey`**\nRotate and retrieve your Lanyard API key (ephemeral)."},
          %{type: 10, content: "**`/stats`**\nView your presence update and Spotify play counts."},
          %{type: 14, divider: true, spacing: 1},
          %{type: 10, content: "-# Admin-only commands accept an optional `user` parameter to manage another user's data."}
        ]
      }
    ]

    DiscordApi.respond_with_components(
      Integer.to_string(data["id"]),
      data["token"],
      components,
      true
    )
  end

  defp handle_apikey(user_id, data) do
    key = rotate_api_key(user_id)
    respond(data, "Your Lanyard API key has been regenerated (only you can see this):\n||#{key}||", ephemeral: true)
  end

  defp handle_stats(user_id, data) do
    analytics = Redis.hgetall("lanyard_analytics:#{user_id}")
    kv = Redis.hgetall("lanyard_kv:#{user_id}")

    presence_updates = Map.get(analytics, "presence_updates", "0")
    spotify_plays = Map.get(analytics, "spotify_plays", "0")
    kv_count = map_size(kv)

    components = [
      %{
        type: 17,
        components: [
          %{type: 10, content: "## Your Lanyard Stats"},
          %{type: 14, divider: true, spacing: 1},
          %{type: 10, content: "**Presence Updates Tracked**\n#{presence_updates}"},
          %{type: 10, content: "**Spotify Plays Tracked**\n#{spotify_plays}"},
          %{type: 10, content: "**KV Keys Stored**\n#{kv_count}"}
        ]
      }
    ]

    DiscordApi.respond_with_components(
      Integer.to_string(data["id"]),
      data["token"],
      components,
      true
    )
  end

  defp set_and_respond(target_id, key, value, data) do
    case KV.set(target_id, key, value) do
      {:ok, _} -> respond(data, "<a:tickmark_cym:1000427958168719390> `#{key}` was set.", ephemeral: true)
      {:error, reason} -> respond(data, ":x: #{reason}", ephemeral: true)
    end
  end

  defp resolve_target(user_id, options, is_admin) do
    requested = Map.get(options, "user")

    cond do
      is_nil(requested) or requested == user_id -> {:ok, user_id}
      is_admin -> {:ok, requested}
      true -> {:error, :no_permission}
    end
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

  defp parse_modal_components(components) do
    Enum.reduce(components, %{}, fn row, acc ->
      Enum.reduce(row["components"] || [], acc, fn comp, inner_acc ->
        Map.put(inner_acc, comp["custom_id"], comp["value"])
      end)
    end)
  end

  defp admin?(data), do: Permissions.admin?(data)

  defp rotate_api_key(user_id) do
    key = Lanyard.DiscordBot.Commands.ApiKey.generate_api_key()

    case Redis.get("user_api_key:#{user_id}") do
      nil -> :ok
      old_key -> Redis.del("api_key:#{old_key}")
    end

    Redis.set("user_api_key:#{user_id}", key)
    Redis.set("api_key:#{key}", user_id)
    key
  end
end
