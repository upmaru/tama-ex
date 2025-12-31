defmodule TamaEx.Memory do
  @moduledoc """
  Client for interacting with Memory API endpoints.
  """

  alias __MODULE__.Entity
  alias __MODULE__.Entity.Params, as: EntityParams
  alias __MODULE__.Entity.Processing, as: EntityProcessing

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

  @doc """
  Retrieves an entity for a class by ID or identifier.

  ## Parameters
    - client - The HTTP client
    - class - The Class struct containing the class_id
    - id_or_identifier - Entity ID or identifier
  """
  def get_entity(client, %TamaEx.Neural.Class{id: class_id}, id_or_identifier)
      when is_binary(class_id) and is_binary(id_or_identifier) do
    with {:ok, validated_client} <- TamaEx.validate_client(client, ["memory"]) do
      url = "/classes/#{class_id}/entities/#{id_or_identifier}"

      validated_client
      |> Req.get(url: url)
      |> TamaEx.handle_response(Entity)
    end
  end

  @doc """
  Updates an entity for a class.

  ## Parameters
    - client - The HTTP client
    - class - The Class struct containing the class_id
    - id - Entity ID or identifier to update
    - attrs - Map containing entity parameters (record is required, identifier and validate_record are optional)

  ## Examples

      iex> attrs = %{"record" => %{"name" => "Updated Name"}}
      iex> {:ok, validated_params} = TamaEx.Memory.Entity.Params.validate_update(attrs)
      iex> validated_params["record"]
      %{"name" => "Updated Name"}

  """
  def update_entity(client, %TamaEx.Neural.Class{id: class_id}, id, attrs, options \\ [])
      when is_binary(class_id) and is_binary(id) do
    processing_params =
      case Keyword.fetch(options, :processing) do
        {:ok, params} -> {:provided, params}
        :error -> :not_provided
      end

    with {:ok, validated_client} <- TamaEx.validate_client(client, ["memory"]),
         {:ok, validated_params} <- EntityParams.validate_update(attrs),
         {:ok, validated_processing_params} <- validate_processing_params(processing_params) do
      url = "/classes/#{class_id}/entities/#{id}"

      body = %{entity: validated_params}

      body = maybe_put_processing(body, validated_processing_params)

      validated_client
      |> Req.patch(url: url, json: body)
      |> TamaEx.handle_response(Entity)
    end
  end

  defp validate_processing_params(:not_provided), do: {:ok, :not_provided}

  defp validate_processing_params({:provided, params}) do
    EntityProcessing.validate(params)
  end

  defp maybe_put_processing(body, :not_provided), do: body
  defp maybe_put_processing(body, params), do: Map.put(body, :processing, params)
end
