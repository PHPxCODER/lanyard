defmodule Lanyard.DiscordBot.Commands.Set do
  alias Lanyard.DiscordBot.DiscordApi
  alias Lanyard.DiscordBot.Commands.ApiKey
  alias Lanyard.DiscordBot.Permissions

  def handle([key | value_s], payload) when length(value_s) > 0 do
    prefix = Application.get_env(:lanyard, :command_prefix)

    result =
      if String.starts_with?(key, "<@") or String.starts_with?(key, "@") do
        {:admin_error, "Prefix commands only work for your own KV. Use `/set` with the `user` option to manage KV for other users."}
      else
        {:ok, payload["author"]["id"], key, Enum.join(value_s, " ")}
      end

    case result do
      {:admin_error, msg} ->
        DiscordApi.send_message(payload["channel_id"], "<a:crossmark_cym:870973061376143431> #{msg}")

      {:ok, target_id, kv_key, value} ->
        do_set(target_id, kv_key, value, payload)
    end

    :ok
  end

  defp do_set(target_id, kv_key, value, payload) do
    case ApiKey.validate_api_key(payload["author"]["id"], kv_key) do
      {true} ->
        DiscordApi.send_message(
          payload["channel_id"],
          "<a:warn_cym:1000445793825734797> Whoops, You Just Posted Your API Key, This is Meant To Stay Private, Regenerating This For You, Check Your DM !"
        )

        ApiKey.generate_and_send_new(payload["author"]["id"])

      {false} ->
        case Lanyard.KV.Interface.set(target_id, kv_key, value) do
          {:error, reason} ->
            DiscordApi.send_message(payload["channel_id"], ":x: #{reason}")

          _ ->
            DiscordApi.send_message(
              payload["channel_id"],
              "<a:tickmark_cym:1000427958168719390> `#{kv_key}` was Set. View it With `#{Application.get_env(:lanyard, :command_prefix)}get #{kv_key}` or go to https://api.phpxcoder.in/v1/users/#{target_id}"
            )
        end
    end

    :ok
  end

  def handle(any, payload) do
    case ApiKey.validate_api_key(payload["author"]["id"], any) do
      [{true}] ->
        DiscordApi.send_message(
          payload["channel_id"],
          "<a:warn_cym:1000445793825734797> Whoops, You Just Posted Your API Key, This is Meant To Stay Private, Regenerating This For You, Check Your DM !"
        )

        ApiKey.generate_and_send_new(payload["author"]["id"])

      [{false}] ->
        DiscordApi.send_message(
          payload["channel_id"],
          "<a:crossmark_cym:870973061376143431> Invalid Usage. Example `set` Command Usage:\n`#{Application.get_env(:lanyard, :command_prefix)}set <key> <value>`"
        )

      _ ->
        :ok
    end

    :ok
  end
end
