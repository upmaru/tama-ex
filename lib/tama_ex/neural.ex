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
  def create_class_operation(client, %Class{id: class_id}, attrs) when is_binary(class_id) do
    with {:ok, validated_client} <- TamaEx.validate_client(client, ["provision"]),
         {:ok, validated_params} <- OperationParams.validate(attrs) do
      url = "/neural/classes/#{class_id}/operations"

      validated_client
      |> Req.post(url: url, json: %{operation: validated_params})
      |> TamaEx.handle_response(Operation)
    end
  end
end
