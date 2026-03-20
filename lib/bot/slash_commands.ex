defmodule Lanyard.DiscordBot.SlashCommands do
  alias Lanyard.DiscordBot.DiscordApi

  @commands [
    %{name: "kv", description: "List your KV keys", type: 1},
    %{
      name: "get",
      description: "Get a KV value",
      type: 1,
      options: [
        %{name: "key", description: "The KV key to retrieve", type: 3, required: true},
        %{name: "user", description: "Target user (admins only)", type: 6, required: false}
      ]
    },
    %{
      name: "set",
      description: "Set a KV value",
      type: 1,
      options: [
        %{name: "user", description: "Target user (admins only)", type: 6, required: false}
      ]
    },
    %{
      name: "del",
      description: "Delete a KV key",
      type: 1,
      options: [
        %{name: "key", description: "The KV key to delete", type: 3, required: true},
        %{name: "user", description: "Target user (admins only)", type: 6, required: false}
      ]
    },
    %{name: "apikey", description: "Get your Lanyard API key (use in DMs)", type: 1},
    %{name: "stats", description: "View your Lanyard presence stats", type: 1},
    %{name: "help", description: "List all available Lanyard commands", type: 1}
  ]

  @doc "Registers all slash commands globally (works in guilds + DMs, up to 1h to propagate)."
  def register_global(app_id) do
    DiscordApi.register_global_commands(app_id, @commands)
  end

  @doc "Registers all slash commands for a specific guild (takes effect instantly)."
  def register(app_id, guild_id) do
    DiscordApi.register_slash_commands(app_id, guild_id, @commands)
  end
end
