defmodule TamaEx.Neural.Class do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:space_id, :string)
    field(:provision_state, :string)
    field(:schema, :map)
    field(:name, :string)
    field(:description, :string)
  end

  @doc false
  def changeset(class, attrs) do
    class
    |> cast(attrs, [:id, :space_id, :provision_state, :schema, :name, :description])
    |> validate_required([:provision_state, :name])
  end

  @doc """
  Parses API response data into a Class struct.

  ## Parameters
    - attrs - Map containing class data from API response

  ## Examples

      iex> Tama.Neural.Class.parse(%{"id" => "123", "name" => "My Class"})
      %Tama.Neural.Class{id: "123", name: "My Class"}

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
  Parses API response data into a Class struct, raising on error.
  """
  def parse!(attrs) do
    case parse(attrs) do
      %__MODULE__{} = class -> class
      _ -> raise "Failed to parse Class data"
    end
  end
end
