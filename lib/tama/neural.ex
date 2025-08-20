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

      iex> Tama.Neural.get_space(client, "my-space")
      {:ok, %Tama.Neural.Space{}}

      iex> Tama.Neural.get_space(client, "nonexistent")
      {:error, :not_found}

  """
  def get_space(client, slug) when is_binary(slug) do
    url = "/neural/spaces/#{slug}"

    client
    |> Req.get(url: url)
    |> TamaEx.handle_response(Space)
  end

  alias __MODULE__.Class

  def get_class(client, %Space{id: space_id}, name) when is_binary(name) do
    url = "/neural/spaces/#{space_id}/classes/#{name}"

    client
    |> Req.get(url: url)
    |> TamaEx.handle_response(Class)
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

      iex> Tama.Neural.create_class_operation(client, %Tama.Neural.Class{id: "class_123"}, %{"chain_ids" => ["chain1"]})
      {:ok, %Tama.Neural.Class.Operation{}}

      iex> Tama.Neural.create_class_operation(client, %Tama.Neural.Class{id: "class_123"}, %{})
      {:error, %Ecto.Changeset{}}

  """
  def create_class_operation(client, %Class{id: class_id}, attrs) when is_binary(class_id) do
    with {:ok, validated_params} <- OperationParams.validate(attrs) do
      url = "/neural/classes/#{class_id}/operations"

      client
      |> Req.post(url: url, json: %{operation: validated_params})
      |> TamaEx.handle_response(Operation)
    end
  end
end
