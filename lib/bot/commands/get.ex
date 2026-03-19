defmodule Lanyard.DiscordBot.Commands.Get do
  alias Lanyard.DiscordBot.DiscordApi
  alias Lanyard.DiscordBot.Commands.ApiKey

  def handle([key], payload) do
    # Admins can prefix with @user to target another user: .get @user key
    # But single-arg form always goes to the normal path
    fetch_kv(payload["author"]["id"], key, payload)
  end

  # Catch mention-style usage and redirect to slash command
  def handle([mention, _key], payload) when is_binary(mention) do
    if String.starts_with?(mention, "<@") or String.starts_with?(mention, "@") do
      DiscordApi.send_message(
        payload["channel_id"],
        "<a:crossmark_cym:870973061376143431> Prefix commands only work for your own KV. Use `/get` with the `user` option to manage KV for other users."
      )
    else
      DiscordApi.send_message(
        payload["channel_id"],
        "<a:crossmark_cym:870973061376143431> Invalid Usage. Example `get` Command Usage:\n`#{Application.get_env(:lanyard, :command_prefix)}get <key>`"
      )
    end
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
          "<a:crossmark_cym:870973061376143431> Invalid Usage. Example `get` Command Usage:\n`#{Application.get_env(:lanyard, :command_prefix)}get <key>`"
        )

      _ ->
        :ok
    end

    :ok
  end

  defp fetch_kv(user_id, key, payload) do
    case ApiKey.validate_api_key(payload["author"]["id"], key) do
      {true} ->
        DiscordApi.send_message(
          payload["channel_id"],
          "<a:warn_cym:1000445793825734797> Whoops, You Just Posted Your API Key, This is Meant To Stay Private, Regenerating This For You, Check Your DM !"
        )

        ApiKey.generate_and_send_new(payload["author"]["id"])

      {false} ->
        case Lanyard.KV.Interface.get(user_id, key) do
          {:ok, v} ->
            DiscordApi.send_message(
              payload["channel_id"],
              "<a:tickmark_cym:1000427958168719390> Key: `#{key}` | Value: ```#{String.replace(v, "`", "`\u200b")}```"
            )

          {:error, msg} ->
            DiscordApi.send_message(payload["channel_id"], "<a:crossmark_cym:870973061376143431> #{msg}")
        end
    end
  end
end
