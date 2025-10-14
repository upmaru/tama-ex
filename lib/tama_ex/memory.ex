defmodule TamaEx.Memory do
  @moduledoc """
  Client for interacting with Memory API endpoints.
  """

  alias __MODULE__.Entity
  alias __MODULE__.Entity.Params, as: EntityParams

  @doc """
  Creates a new entity for a class.

  ## Parameters
    - client - The HTTP client
    - class - The Class struct containing the class_id
    - attrs - Map containing entity parameters (identifier, record, validate_record)

  ## Examples

      iex> attrs = %{"identifier" => "entity1", "record" => %{}}
      iex> {:ok, validated_params} = TamaEx.Memory.Entity.Params.validate(attrs)
      iex> validated_params["identifier"]
      "entity1"

      iex> {:error, changeset} = TamaEx.Memory.Entity.Params.validate(%{})
      iex> changeset.valid?
      false

  """
  def create_entity(client, %TamaEx.Neural.Class{id: class_id}, attrs) when is_binary(class_id) do
    with {:ok, validated_client} <- TamaEx.validate_client(client, ["memory"]),
         {:ok, validated_params} <- EntityParams.validate(attrs) do
      url = "/classes/#{class_id}/entities"

      validated_client
      |> Req.post(url: url, json: %{entity: validated_params})
      |> TamaEx.handle_response(Entity)
    end
  end
end
