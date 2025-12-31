defmodule TamaEx.Neural do
  @moduledoc """
  Client for interacting with Neural API endpoints.
  """

  alias __MODULE__.Space

  @doc """
  Gets a space by slug from the provision endpoint.

  ## Parameters
    - :provision - The endpoint type (currently only :provision is supported)
    - slug - The slug identifier for the space

  ## Examples

      iex> TamaEx.Neural.get_space(client, "my-space")
      {:ok, %TamaEx.Neural.Space{}}

      iex> TamaEx.Neural.get_space(client, "nonexistent")
      {:error, :not_found}

  """
  def get_space(client, slug) when is_binary(slug) do
    with {:ok, validated_client} <- TamaEx.validate_client(client, ["provision"]) do
      url = "/neural/spaces/#{slug}"

      validated_client
      |> Req.get(url: url)
      |> TamaEx.handle_response(Space)
    end
  end

  alias __MODULE__.Class

  def get_class(client, %Space{id: space_id}, name) when is_binary(name) do
    with {:ok, validated_client} <- TamaEx.validate_client(client, ["provision"]) do
      url = "/neural/spaces/#{space_id}/classes/#{name}"

      validated_client
      |> Req.get(url: url)
      |> TamaEx.handle_response(Class)
    end
  end

  alias __MODULE__.Class.Operation
  alias __MODULE__.Class.Operation.Params, as: OperationParams

  @doc """
  Creates a new operation for a class.

  ## Parameters
    - client - The HTTP client
    - class - The Class struct containing the class_id
    - attrs - Map containing operation parameters (chain_ids, node_type)

  ## Examples

      iex> TamaEx.Neural.create_class_operation(client, %TamaEx.Neural.Class{id: "class_123"}, %{"chain_ids" => ["chain1"]})
      {:ok, %TamaEx.Neural.Class.Operation{}}

      iex> TamaEx.Neural.create_class_operation(client, %TamaEx.Neural.Class{id: "class_123"}, %{})
      {:error, %Ecto.Changeset{}}

  """
  def create_class_operation(client, %Class{id: class_id}, attrs) do
    with {:ok, validated_client} <- TamaEx.validate_client(client, ["provision"]),
         {:ok, validated_params} <- OperationParams.validate(attrs) do
      url = "/neural/classes/#{class_id}/operations"

      validated_client
      |> Req.post(url: url, json: %{operation: validated_params})
      |> TamaEx.handle_response(Operation)
    end
  end

  alias __MODULE__.Node

  @doc """
  Lists nodes for a class.

  ## Parameters
    - client - The HTTP client
    - class - The Class struct containing the class_id
    - options - Keyword list of options (optional)
      - :query - Query parameters to pass to the API

  ## Examples

      iex> TamaEx.Neural.list_nodes(client, %TamaEx.Neural.Class{id: "class_123"})
      {:ok, [%TamaEx.Neural.Node{}]}

      iex> TamaEx.Neural.list_nodes(client, %TamaEx.Neural.Class{id: "class_123"}, query: [limit: 10])
      {:ok, [%TamaEx.Neural.Node{}]}

  """
  def list_nodes(client, %Class{id: class_id}, options \\ []) do
    with {:ok, validated_client} <- TamaEx.validate_client(client, ["neural"]) do
      url = "/classes/#{class_id}/nodes"

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
      |> TamaEx.handle_response(Node)
    end
  end
end
