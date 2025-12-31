defmodule TamaEx.Neural.Node do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :binary_id
    field :type, :string
    field :on, :string
    field :provision_state, :string

    embeds_one :chain, Chain, primary_key: false do
      field :id, :binary_id
      field :name, :string
    end
  end

  def changeset(node, attrs) do
    node
    |> cast(attrs, [:id, :type, :on, :provision_state])
    |> validate_required([:id, :type])
    |> cast_embed(:chain, with: &chain_changeset/2)
  end

  defp chain_changeset(chain, attrs) do
    chain
    |> cast(attrs, [:id, :name])
    |> validate_required([:id, :name])
  end

  @doc """
  Parses API response data into Node struct(s).

  Handles both individual node maps and lists of nodes.
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
  Parses API response data into a Node struct, raising on error.
  """
  def parse!(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action!(:insert)
  end
end
