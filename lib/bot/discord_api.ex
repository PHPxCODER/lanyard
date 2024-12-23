defmodule Lanyard.DiscordBot.DiscordApi do
  @api_host "https://discord.com/api/v9"

  def send_message(channel_id, content) when is_binary(content) do
    Lanyard.Metrics.Collector.inc(:counter, :lanyard_discord_messages_sent)

    sanitized_content =
      content
      |> String.replace("@", "@​\u200b")

    HTTPoison.post(
      "#{@api_host}/channels/#{channel_id}/messages",
      Poison.encode!(%{content: sanitized_content}),
      [
        {"Authorization", "Bot " <> Application.get_env(:lanyard, :bot_token)},
        {"Content-Type", "application/json"}
      ]
    )
  end

  def create_dm(recipient) do
    {:ok, response} =
      HTTPoison.post(
        "#{@api_host}/users/@me/channels",
        Poison.encode!(%{recipient_id: recipient}),
        [
          {"Authorization", "Bot " <> Application.get_env(:lanyard, :bot_token)},
          {"Content-Type", "application/json"}
        ]
      )

    case Poison.decode!(response.body) do
      %{"id" => id} ->
        id

      _ ->
        :ok
    end
  end
end
