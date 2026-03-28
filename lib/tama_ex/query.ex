defmodule TamaEx.Query do
  @moduledoc false

  def flatten(params) when is_map(params) do
    params
    |> normalize_map()
    |> Enum.flat_map(fn {key, value} -> flatten_param([to_string(key)], value) end)
  end

  defp flatten_param(keys, value) when is_map(value) do
    value
    |> normalize_map()
    |> Enum.flat_map(fn {nested_key, nested_value} ->
      flatten_param(keys ++ [to_string(nested_key)], nested_value)
    end)
  end

  defp flatten_param(keys, value), do: [{encode_key(keys), value}]

  defp normalize_map(%_{} = struct), do: Map.from_struct(struct)
  defp normalize_map(map) when is_map(map), do: map

  defp encode_key([key]), do: key

  defp encode_key([key | rest]) do
    Enum.reduce(rest, key, fn part, acc -> "#{acc}[#{part}]" end)
  end
end
