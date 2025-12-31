defmodule TamaEx.Memory.Entity.Processing do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :chain_slugs, {:array, :string}, default: []
    field :chain_ids, {:array, :string}, default: []

    field :node_type, Ecto.Enum, values: [:explicit, :reactive]
  end

  def changeset(processing, attrs) do
    processing
    |> cast(attrs, [:chain_slugs, :chain_ids, :node_type])
    |> validate_required([:chain_slugs, :chain_ids, :node_type])
  end

  @doc """
  Validates and prepares processing parameters.
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
  Validates processing parameters and raises on error.
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
      "chain_slugs" => data.chain_slugs,
      "chain_ids" => data.chain_ids,
      "node_type" => format_node_type(data.node_type)
    }
  end

  defp format_node_type(node_type) when is_atom(node_type), do: Atom.to_string(node_type)
  defp format_node_type(node_type), do: node_type
end
