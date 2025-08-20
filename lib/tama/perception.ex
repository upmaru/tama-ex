defmodule TamaEx.Perception do
  @moduledoc """
  Client for interacting with Perception API endpoints.
  """

  alias __MODULE__.Chain

  @doc """
  Gets a chain by slug from a specific space.

  ## Parameters
    - client - The HTTP client
    - space - The space identifier (can be space_id string or Space struct)
    - slug - The slug identifier for the chain

  ## Examples

      iex> TamaEx.Perception.get_chain(client, "space_123", "my-chain")
      {:ok, %TamaEx.Perception.Chain{}}

      iex> TamaEx.Perception.get_chain(client, %TamaEx.Neural.Space{id: "space_123"}, "my-chain")
      {:ok, %TamaEx.Perception.Chain{}}

      iex> TamaEx.Perception.get_chain(client, "space_123", "nonexistent")
      {:error, :not_found}

  """
  def get_chain(client, %TamaEx.Neural.Space{id: space_id}, slug)
      when is_binary(slug) do
    with {:ok, validated_client} <- TamaEx.validate_client(client, ["provision"]) do
      get_chain(validated_client, space_id, slug)
    end
  end

  def get_chain(client, space_id, slug) when is_binary(space_id) and is_binary(slug) do
    with {:ok, validated_client} <- TamaEx.validate_client(client, ["provision"]) do
      url = "/perception/spaces/#{space_id}/chains/#{slug}"

      validated_client
      |> Req.get(url: url)
      |> TamaEx.handle_response(Chain)
    end
  end
end
