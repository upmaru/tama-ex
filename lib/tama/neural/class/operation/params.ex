defmodule Tama.Neural.Class.Operation.Params do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:chain_ids, {:array, :string})
    field(:node_type, :string)
  end

  @doc false
  def changeset(params, attrs) do
    params
    |> cast(attrs, [:chain_ids, :node_type])
    |> validate_required([:chain_ids])
    |> validate_length(:chain_ids, min: 1, message: "must have at least one chain ID")
  end

  @doc """
  Validates and prepares parameters for creating a class operation.

  ## Parameters
    - attrs - Map containing operation parameters

  ## Examples

      iex> Tama.Neural.Class.Operation.Params.validate(%{"chain_ids" => ["chain1", "chain2"]})
      {:ok, %{"chain_ids" => ["chain1", "chain2"]}}

      iex> Tama.Neural.Class.Operation.Params.validate(%{})
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
      "chain_ids" => data.chain_ids
    }
    |> maybe_put_node_type(data.node_type)
  end

  defp maybe_put_node_type(body, nil), do: body
  defp maybe_put_node_type(body, node_type), do: Map.put(body, "node_type", node_type)
end
