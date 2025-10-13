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

      iex> client = %Req.Request{options: %{base_url: "https://api.example.com/provision"}}
      iex> {:ok, _} = TamaEx.validate_client(client, ["provision"])
      iex> is_binary("space_123") and is_binary("my-chain")
      true

      iex> space = %TamaEx.Neural.Space{id: "space_123", name: "Test", provision_state: "active"}
      iex> space.id
      "space_123"

      iex> attrs = %{"name" => "Test Chain", "provision_state" => "active"}
      iex> chain = TamaEx.Perception.Chain.parse(attrs)
      iex> chain.name
      "Test Chain"

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

  alias __MODULE__.Concept

  def list_concepts(client, entity_id, options \\ []) do
    with {:ok, validated_client} <- TamaEx.validate_client(client, ["perception"]) do
      url = "/entities/#{entity_id}/concepts"

      query = Keyword.get(options, :query, [])

      req_options = [url: url, params: query]

      req_options =
        if Keyword.has_key?(options, :retry) do
          Keyword.put(req_options, :retry, Keyword.get(options, :retry))
        else
          req_options
        end

      validated_client
      |> Req.get(req_options)
      |> TamaEx.handle_response(Concept)
    end
  end
end
