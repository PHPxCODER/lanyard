defmodule Lanyard.DiscordBot.Commands.KV do
  alias Lanyard.DiscordBot.DiscordApi

  def handle(_, payload) do
    kv =
      Lanyard.KV.Interface.get_all(payload["author"]["id"])
      |> Enum.map(fn {k, _v} -> k end)
      |> Enum.join(", ")

    kv = if String.length(kv) > 0, do: kv, else: "No keys"

    DiscordApi.send_message(
      payload["channel_id"],
      "*`#{Application.get_env(:lanyard, :command_prefix)}get <key>` To Get a Value*\n*`#{Application.get_env(:lanyard, :command_prefix)}del <key>` To Delete an Existing Key*\n*`#{Application.get_env(:lanyard, :command_prefix)}set <key> <value>` To Set a Key*\n\n**Keys:** ```#{kv}```"
    )
  end
end
