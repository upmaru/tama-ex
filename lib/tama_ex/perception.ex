defmodule TamaEx.Perception do
  @moduledoc """
  Client for interacting with Perception API endpoints.
  """

  alias __MODULE__.Chain
  alias TamaEx.Query

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

  def get_chain(client, id) when is_binary(id) do
    with {:ok, validated_client} <- TamaEx.validate_client(client, ["provision"]) do
      url = "/perception/chains/#{id}"

      validated_client
      |> Req.get(url: url)
      |> TamaEx.handle_response(Chain)
    end
  end

  alias __MODULE__.Concept

  @doc """
  Lists concepts from the perception namespace.

  This function supports both perception concept endpoints:

  - `list_concepts/2` calls `GET /perception/concepts`
  - `list_concepts/3` calls `GET /perception/entities/:entity_id/concepts`

  Query params can be passed as either a keyword list or a map.
  When a map is provided, nested maps are flattened into bracketed query params.

  ## Parameters

    - client - The HTTP client configured for the `perception` namespace
    - entity_id - Optional entity identifier for the entity-specific concepts endpoint
    - options - Optional request options
    - query - Optional query params as a keyword list or nested map
    - retry - Optional `Req` retry option

  ## Examples

      iex> client = %Req.Request{options: %{base_url: "https://api.example.com/perception"}}
      iex> {:ok, _} = TamaEx.validate_client(client, ["perception"])
      iex> is_list([])
      true

      iex> query = %{
      ...>   actor: %{source: "system", identifier: "agent_123"},
      ...>   tool_call_id: "tool-call-123"
      ...> }
      iex> TamaEx.Query.flatten(query)
      [{"actor[source]", "system"}, {"actor[identifier]", "agent_123"}, {"tool_call_id", "tool-call-123"}]

      iex> entity_query = %{
      ...>   generator: %{type: "model"},
      ...>   relations: "reply"
      ...> }
      iex> TamaEx.Query.flatten(entity_query)
      [{"generator[type]", "model"}, {"relations", "reply"}]

  Example usage:

      TamaEx.Perception.list_concepts(client,
        query: %{
          actor: %{
            source: actor.source,
            identifier: actor.identifier
          },
          tool_call_id: "tool-call-123"
        }
      )

      TamaEx.Perception.list_concepts(client, entity_id,
        query: %{
          generator: %{type: "model"},
          relations: "reply"
        }
      )

  """
  def list_concepts(client), do: list_concepts(client, [])

  def list_concepts(client, options) when is_list(options) do
    with {:ok, validated_client} <- TamaEx.validate_client(client, ["perception"]) do
      url = "/concepts"
      query = normalize_query(Keyword.get(options, :query, []))

      req_options = build_request_options(url, query, options)

      validated_client
      |> Req.get(req_options)
      |> TamaEx.handle_response(Concept)
    end
  end

  def list_concepts(client, entity_id) when is_binary(entity_id) do
    list_concepts(client, entity_id, [])
  end

  def list_concepts(client, entity_id, options) when is_binary(entity_id) do
    with {:ok, validated_client} <- TamaEx.validate_client(client, ["perception"]) do
      url = "/entities/#{entity_id}/concepts"
      query = normalize_query(Keyword.get(options, :query, []))
      req_options = build_request_options(url, query, options)

      validated_client
      |> Req.get(req_options)
      |> TamaEx.handle_response(Concept)
    end
  end

  defp build_request_options(url, query, options) do
    req_options = [url: url, params: query]

    if Keyword.has_key?(options, :retry) do
      Keyword.put(req_options, :retry, Keyword.get(options, :retry))
    else
      req_options
    end
  end

  defp normalize_query(query) when is_list(query), do: query
  defp normalize_query(query) when is_map(query), do: Query.flatten(query)
end
