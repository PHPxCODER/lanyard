defmodule Lanyard.DiscordBot.DiscordApi do
  @api_host "https://discord.com/api/v10"

  defp headers(extra \\ []) do
    [
      {"Authorization", "Bot " <> Application.get_env(:lanyard, :bot_token)},
      {"Content-Type", "application/json"}
    ] ++ extra
  end

  defp post(url, body, opts \\ []) do
    Finch.build(:post, url, headers(opts), Jason.encode!(body))
    |> Finch.request(Lanyard.Finch)
  end

  defp put(url, body) do
    Finch.build(:put, url, headers(), Jason.encode!(body))
    |> Finch.request(Lanyard.Finch)
  end

  def send_message(channel_id, content) when is_binary(content) do
    Lanyard.Metrics.Collector.inc(:counter, :lanyard_discord_messages_sent)

    sanitized_content = String.replace(content, "@", "@​\u200b")

    post("#{@api_host}/channels/#{channel_id}/messages", %{content: sanitized_content})
  end

  def register_global_commands(app_id, commands) do
    put("#{@api_host}/applications/#{app_id}/commands", commands)
  end

  def register_slash_commands(app_id, guild_id, commands) do
    put("#{@api_host}/applications/#{app_id}/guilds/#{guild_id}/commands", commands)
  end

  def respond_to_interaction(interaction_id, interaction_token, content, ephemeral \\ false) do
    flags = if ephemeral, do: 64, else: 0

    post(
      "#{@api_host}/interactions/#{interaction_id}/#{interaction_token}/callback",
      %{type: 4, data: %{content: content, flags: flags}},
      []
    )
  end

  def respond_with_modal(interaction_id, interaction_token, modal) do
    post(
      "#{@api_host}/interactions/#{interaction_id}/#{interaction_token}/callback",
      %{type: 9, data: modal},
      []
    )
  end

  def respond_with_components(interaction_id, interaction_token, components, ephemeral \\ false) do
    # 32768 = IS_COMPONENTS_V2 flag (1 <<< 15); combined with ephemeral (64) = 32832
    flags = if ephemeral, do: 32832, else: 32768

    post(
      "#{@api_host}/interactions/#{interaction_id}/#{interaction_token}/callback",
      %{type: 4, data: %{flags: flags, components: components}},
      []
    )
  end

  def create_dm(recipient) do
    case post("#{@api_host}/users/@me/channels", %{recipient_id: recipient}) do
      {:ok, %Finch.Response{body: body}} ->
        case Jason.decode!(body) do
          %{"id" => id} -> {:ok, id}
          _ -> {:error, :missing_id}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
