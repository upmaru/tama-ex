defmodule TamaEx.Perception.Chain do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:space_id, :string)
    field(:name, :string)
    field(:slug, :string)
    field(:provision_state, :string)
  end

  @doc false
  def changeset(chain, attrs) do
    chain
    |> cast(attrs, [:id, :space_id, :name, :slug, :provision_state])
    |> validate_required([:name, :provision_state])
  end

  @doc """
  Parses API response data into a Chain struct.

  ## Parameters
    - attrs - Map containing chain data from API response

  ## Examples

      iex> TamaEx.Perception.Chain.parse(%{"id" => "123", "name" => "My Chain"})
      %TamaEx.Perception.Chain{id: "123", name: "My Chain"}

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
  Parses API response data into a Chain struct, raising on error.
  """
  def parse!(attrs) do
    case parse(attrs) do
      %__MODULE__{} = chain -> chain
      _ -> raise "Failed to parse Chain data"
    end
  end
end
