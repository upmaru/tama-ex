defmodule TamaEx.Perception.Concept do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :binary_id
    field :relation, :string
    field :content, :map
  end

  def changeset(concept, attrs) do
    concept
    |> cast(attrs, [:id, :relation, :content])
    |> validate_required([:id, :relation, :content])
  end

  @doc """
  Parses API response data into Concept struct(s).

  Handles both individual concept maps and lists of concepts.
  """
  def parse(attrs) when is_list(attrs) do
    Enum.map(attrs, &parse/1)
  end

  def parse(attrs) when is_map(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> case do
      %Ecto.Changeset{valid?: true} = changeset ->
        Ecto.Changeset.apply_changes(changeset)

      %Ecto.Changeset{valid?: false} ->
        %__MODULE__{}
    end
  end

  def parse(attrs) when is_binary(attrs) do
    case Jason.decode(attrs) do
      {:ok, decoded} -> parse(decoded)
      {:error, _} -> %__MODULE__{}
    end
  end

  def parse(_), do: %__MODULE__{}

  @doc """
  Parses API response data into a Concept struct, raising on error.
  """
  def parse!(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action!(:insert)
  end
end
