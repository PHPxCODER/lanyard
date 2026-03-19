defmodule Lanyard.DiscordBot.Permissions do
  import Bitwise

  @administrator 0x8
  @manage_guild 0x20

  @doc "Returns true if the message author has Administrator or Manage Guild permission."
  def admin?(payload) do
    case get_in(payload, ["member", "permissions"]) do
      perms when is_binary(perms) ->
        perm_int = String.to_integer(perms)
        (perm_int &&& @administrator) != 0 or (perm_int &&& @manage_guild) != 0

      perms when is_integer(perms) ->
        (perms &&& @administrator) != 0 or (perms &&& @manage_guild) != 0

      _ ->
        false
    end
  end

  @doc "Parses a Discord user mention (<@USER_ID> or <@!USER_ID>) and returns {:ok, user_id} or :error."
  def parse_user_mention(str) do
    case Regex.run(~r/^<@!?(\d+)>$/, str) do
      [_, user_id] -> {:ok, user_id}
      _ -> :error
    end
  end
end
