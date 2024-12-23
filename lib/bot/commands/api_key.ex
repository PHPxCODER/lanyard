defmodule Lanyard.DiscordBot.Commands.ApiKey do
  alias Lanyard.Connectivity.Redis
  alias Lanyard.DiscordBot.DiscordApi

  def handle(_, %{"channel_id" => channel_id, guild_id: _guild_id} = p) do
    DiscordApi.send_message(channel_id, "<a:crossmark_cym:870973061376143431> You Can Only Perform This Command in DMs With Me !")
  end

  def handle(_, payload) do
    key = generate_api_key()

    existing_key? = Redis.get("user_api_key:#{payload["author"]["id"]}")

    if existing_key? do
      Redis.del("api_key:#{existing_key?}")
    end

    Redis.set("api_key:#{key}", payload["author"]["id"])
    Redis.set("user_api_key:#{payload["author"]["id"]}", key)

    DiscordApi.send_message(
      payload["channel_id"],
      "<a:tickmark_cym:1000427958168719390> Your New Lanyard API Key is `#{key}`\n\n**ABSOLUTELY DO NOT SHARE OR POST THIS KEY ANYWHERE IT WILL ALLOW ANYONE TO MANAGE YOUR LANYARD K/V**\n<:verified_cym:1000433632692940820> *Run This Command Again If You Need To Re-Generate Your API Key*"
    )
  end

  def validate_api_key(user_id, key) when is_binary(key) do
    case Redis.get("user_api_key:#{user_id}") do
      ^key ->
        {true}

      _ ->
        {false}
    end
  end

  def validate_api_key(user_id, key) when is_list(key) do
    Enum.map(key, fn apikey ->
      case Redis.get("user_api_key:#{user_id}") do
        ^apikey ->
          {true}

        _ ->
          {false}
      end
    end)
  end

  def generate_and_send_new(user_id) do
    key = generate_api_key()
    existing_key? = Redis.get("user_api_key:#{user_id}")

    if existing_key? do
      Redis.del("api_key:#{existing_key?}")
    end

    Redis.set("api_key:#{key}", user_id)
    Redis.set("user_api_key:#{user_id}", key)

    dm_channel = DiscordApi.create_dm(user_id)

    DiscordApi.send_message(
      dm_channel,
      "<a:tickmark_cym:1000427958168719390> **We've Regenerated Your API Key As You Used It in a K/V Command.**\nYour New Lanyard API Key is `#{key}`\n\n**ABSOLUTELY DO NOT SHARE OR POST THIS KEY ANYWHERE IT WILL ALLOW ANYONE TO MANAGE YOUR LANYARD K/V**\n<:verified_cym:1000433632692940820> *Run `.apikey` in This DM If You Need To Re-Generate Your Key*"
    )
  end

  def generate_api_key() do
    symbols = '0123456789abcdef'
    symbol_count = Enum.count(symbols)
    for _ <- 1..32, into: "", do: <<Enum.at(symbols, :crypto.rand_uniform(0, symbol_count))>>
  end
end
