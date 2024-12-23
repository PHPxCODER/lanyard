defmodule Lanyard.KV.Interface do
  alias Lanyard.Connectivity.Redis
  alias Lanyard.Presence

  def get_all(user_id) do
    {:ok, %{kv: kv}} = Presence.get_presence(user_id)
    kv
  end

  def get(user_id, key) do
    case Presence.get_presence(user_id) do
      {:ok, %{kv: %{^key => value}}} ->
        {:ok, value}

      _ ->
        {:error, "Key #{key} Not Found in KV"}
    end
  end

  def set(user_id, key, value) do
    kv = get_all(user_id)

    cond do
      Map.keys(kv) |> length > 511 ->
        {:error, "Request would Exceed Key Limit (512), Please Delete Keys First"}

      true ->
        case validate_pair({key, value}) do
          {:error, _msg} = err ->
            err

          {:ok} ->
            Redis.hset("lanyard_kv:#{user_id}", key, value)
            Presence.sync(user_id, %{kv: Map.put(kv, key, value)})
            {:ok, value}
        end
    end
  end

  def multiset(user_id, map) when is_map(map) do
    Redis.hset("lanyard_kv:#{user_id}", map_to_list(map))

    full_kv = get_all(user_id)
    Presence.sync(user_id, %{kv: Map.merge(full_kv, map)})
  end

  def del(user_id, key) do
    Redis.hdel("lanyard_kv:#{user_id}", key)

    kv = get_all(user_id)
    Presence.sync(user_id, %{kv: Map.delete(kv, key)})
  end

  def validate_pair({key, value}) do
    cond do
      String.length(key) > 255 ->
        {:error, "Key must be 255 Characters or Less"}

      not String.match?(key, ~r/^[a-zA-Z0-9_]*$/) ->
        {:error, "Key must be Alphanumeric (a-zA-Z0-9_)"}

      String.length(value) > 30000 ->
        {:error, "Value must be 30000 Characters or Less"}

      true ->
        {:ok}
    end
  end

  defp map_to_list(map) when is_map(map) do
    map |> Enum.reduce([], fn {k, v}, acc -> [k, v | acc] end)
  end
end
