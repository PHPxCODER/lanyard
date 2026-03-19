defmodule Lanyard.DiscordBot.Commands.Stats do
  alias Lanyard.DiscordBot.DiscordApi
  alias Lanyard.Connectivity.Redis

  def handle(_, payload) do
    user_id = payload["author"]["id"]

    analytics = Redis.hgetall("lanyard_analytics:#{user_id}")
    kv = Redis.hgetall("lanyard_kv:#{user_id}")

    presence_updates = Map.get(analytics, "presence_updates", "0")
    spotify_plays = Map.get(analytics, "spotify_plays", "0")
    kv_count = map_size(kv)

    DiscordApi.send_message(payload["channel_id"], """
    <a:tickmark_cym:1000427958168719390> **Your Lanyard Stats**
    > Presence Updates Tracked: **#{presence_updates}**
    > Spotify Plays Tracked: **#{spotify_plays}**
    > KV Keys Stored: **#{kv_count}**
    """)
  end
end
