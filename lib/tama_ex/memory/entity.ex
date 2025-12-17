defmodule TamaEx.Memory.Entity do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :string
    field :class_id, :string
    field :current_state, :string
    field :identifier, :string
    field :record, :map
  end

  @doc false
  def changeset(entity, attrs) do
    entity
    |> cast(attrs, [:id, :class_id, :current_state, :identifier, :record])
    |> validate_required([:class_id, :current_state, :identifier, :record])
  end

  @doc """
  Parses API response data into an Entity struct.

  ## Parameters
  	- attrs - Map containing entity data from API response

  ## Examples

  		iex> TamaEx.Memory.Entity.parse(%{"id" => "123", "identifier" => "my-entity"})
  		%TamaEx.Memory.Entity{id: "123", identifier: "my-entity"}

  """
  def parse(attrs) when is_map(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action!(:insert)
  end

  def parse(attrs) when is_binary(attrs) do
    case Jason.decode(attrs) do
      {:ok, decoded} -> parse(decoded)
      {:error, _} -> %__MODULE__{}
    end
  end

  def parse(_), do: %__MODULE__{}

  @doc """
  Parses API response data into an Entity struct, raising on error.
  """
  def parse!(attrs) do
    case parse(attrs) do
      %__MODULE__{} = entity -> entity
      _ -> raise "Failed to parse Entity data"
    end
  end
end
