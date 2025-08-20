defmodule TamaEx.Neural.Class.Operation do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :string
    field :current_state, :string
    field :class_id, :string
    field :node_ids, {:array, :string}
  end

  @doc false
  def changeset(operation, attrs) do
    operation
    |> cast(attrs, [:id, :current_state, :class_id, :node_ids])
    |> validate_required([:current_state, :class_id])
  end

  @doc """
  Parses API response data into an Operation struct.

  ## Parameters
    - attrs - Map containing operation data from API response

  ## Examples

      iex> TamaEx.Neural.Class.Operation.parse(%{"id" => "123", "current_state" => "running", "class_id" => "class_1"})
      %TamaEx.Neural.Class.Operation{id: "123", current_state: "running", class_id: "class_1"}

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
  Parses API response data into an Operation struct, raising on error.
  """
  def parse!(attrs) do
    case parse(attrs) do
      %__MODULE__{} = operation -> operation
      _ -> raise "Failed to parse Operation data"
    end
  end
end
