defmodule Lanyard.DiscordBot.Commands.Get do
  alias Lanyard.DiscordBot.DiscordApi
  alias Lanyard.DiscordBot.Commands.ApiKey

  def handle([key], payload) do
    case ApiKey.validate_api_key(payload["author"]["id"], key) do
      {true} ->
        DiscordApi.send_message(
          payload["channel_id"],
          "<a:warn_cym:1000445793825734797> Whoops, You Just Posted Your API Key, This is Meant To Stay Private, Regenerating This For You, Check Your DM !"
        )

        ApiKey.generate_and_send_new(payload["author"]["id"])

      {false} ->
        case Lanyard.KV.Interface.get(payload["author"]["id"], key) do
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
end
