defmodule TamaEx.Memory.Entity.Params do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :identifier, :string
    field :record, :map
    field :validate_record, :boolean, default: true
  end

  @doc false
  def changeset(params, attrs) do
    params
    |> cast(attrs, [:identifier, :record, :validate_record])
    |> validate_required([:identifier, :record])
  end

  @doc false
  def update_changeset(params, attrs) do
    params
    |> cast(attrs, [:identifier, :record, :validate_record])
    |> validate_required([:record])
  end

  @doc """
  Validates and prepares parameters for creating an entity.

  ## Parameters
    - attrs - Map containing entity parameters

  ## Examples

      iex> TamaEx.Memory.Entity.Params.validate(%{"identifier" => "my-entity", "record" => %{"name" => "test"}})
      {:ok, %{"identifier" => "my-entity", "record" => %{"name" => "test"}, "validate_record" => true}}

      iex> TamaEx.Memory.Entity.Params.validate(%{})
      {:error, %Ecto.Changeset{}}

  """
  def validate(attrs) when is_map(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> case do
      %Ecto.Changeset{valid?: true} = changeset ->
        {:ok, to_request_body(changeset)}

      changeset ->
        {:error, changeset}
    end
  end

  @doc """
  Validates parameters and raises on error.
  """
  def validate!(attrs) do
    case validate(attrs) do
      {:ok, params} -> params
      {:error, changeset} -> raise Ecto.InvalidChangesetError, changeset: changeset
    end
  end

  @doc """
  Validates and prepares parameters for updating an entity.
  Only requires record field, identifier is optional.

  ## Parameters
    - attrs - Map containing entity parameters

  ## Examples

      iex> TamaEx.Memory.Entity.Params.validate_update(%{"record" => %{"name" => "updated"}})
      {:ok, %{"record" => %{"name" => "updated"}, "validate_record" => true}}

      iex> TamaEx.Memory.Entity.Params.validate_update(%{"identifier" => "new-id", "record" => %{"name" => "test"}})
      {:ok, %{"identifier" => "new-id", "record" => %{"name" => "test"}, "validate_record" => true}}

      iex> TamaEx.Memory.Entity.Params.validate_update(%{})
      {:error, %Ecto.Changeset{}}

  """
  def validate_update(attrs) when is_map(attrs) do
    %__MODULE__{}
    |> update_changeset(attrs)
    |> case do
      %Ecto.Changeset{valid?: true} = changeset ->
        {:ok, to_update_request_body(changeset)}

      changeset ->
        {:error, changeset}
    end
  end

  @doc """
  Validates update parameters and raises on error.
  """
  def validate_update!(attrs) do
    case validate_update(attrs) do
      {:ok, params} -> params
      {:error, changeset} -> raise Ecto.InvalidChangesetError, changeset: changeset
    end
  end

  @doc """
  Converts validated changeset to request body format.
  """
  def to_request_body(%Ecto.Changeset{valid?: true} = changeset) do
    data = apply_changes(changeset)

    %{
      "identifier" => data.identifier,
      "record" => data.record,
      "validate_record" => data.validate_record
    }
  end

  @doc """
  Converts validated update changeset to request body format.
  Only includes fields that are present.
  """
  def to_update_request_body(%Ecto.Changeset{valid?: true} = changeset) do
    data = apply_changes(changeset)

    %{
      "record" => data.record,
      "validate_record" => data.validate_record
    }
    |> maybe_put("identifier", data.identifier)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
