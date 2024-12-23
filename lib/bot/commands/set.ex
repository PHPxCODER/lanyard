defmodule Lanyard.DiscordBot.Commands.Set do
  alias Lanyard.DiscordBot.DiscordApi
  alias Lanyard.DiscordBot.Commands.ApiKey

  def handle([key | value_s], payload) when length(value_s) > 0 do
    value = Enum.join(value_s, " ")

    case ApiKey.validate_api_key(payload["author"]["id"], key) do
      {true} ->
        DiscordApi.send_message(
          payload["channel_id"],
          "<a:warn_cym:1000445793825734797> Whoops, You Just Posted Your API Key, This is Meant To Stay Private, Regenerating This For You, Check Your DM !"
        )

        ApiKey.generate_and_send_new(payload["author"]["id"])

      {false} ->
        case Lanyard.KV.Interface.set(payload["author"]["id"], key, value) do
          {:error, reason} ->
            DiscordApi.send_message(
              payload["channel_id"],
              ":x: #{reason}"
            )

          _ ->
            DiscordApi.send_message(
              payload["channel_id"],
              "<a:tickmark_cym:1000427958168719390> `#{key}` was Set. View it With `#{Application.get_env(:lanyard, :command_prefix)}get #{key}` or go to https://api.codevizag.com/v1/users/#{payload["author"]["id"]}"
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
