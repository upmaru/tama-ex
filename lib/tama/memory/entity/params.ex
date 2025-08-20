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
end
