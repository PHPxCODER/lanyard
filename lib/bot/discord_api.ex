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

  def register_global_commands(app_id, commands) do
    HTTPoison.put(
      "#{@api_host}/applications/#{app_id}/commands",
      Poison.encode!(commands),
      [
        {"Authorization", "Bot " <> Application.get_env(:lanyard, :bot_token)},
        {"Content-Type", "application/json"}
      ]
    )
  end

  def register_slash_commands(app_id, guild_id, commands) do
    HTTPoison.put(
      "#{@api_host}/applications/#{app_id}/guilds/#{guild_id}/commands",
      Poison.encode!(commands),
      [
        {"Authorization", "Bot " <> Application.get_env(:lanyard, :bot_token)},
        {"Content-Type", "application/json"}
      ]
    )
  end

  def respond_to_interaction(interaction_id, interaction_token, content, ephemeral \\ false) do
    flags = if ephemeral, do: 64, else: 0

    HTTPoison.post(
      "#{@api_host}/interactions/#{interaction_id}/#{interaction_token}/callback",
      Poison.encode!(%{type: 4, data: %{content: content, flags: flags}}),
      [{"Content-Type", "application/json"}]
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
