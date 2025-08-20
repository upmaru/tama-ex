defmodule Tama.Neural.Space do
  @moduledoc """
  Embedded schema for Neural Space entities.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:id, :string)
    field(:name, :string)
    field(:slug, :string)
    field(:type, :string)
    field(:provision_state, :string)
  end

  @doc false
  def changeset(space, attrs) do
    space
    |> cast(attrs, [:id, :name, :slug, :type, :provision_state])
    |> validate_required([:name, :type, :provision_state])
  end

  @doc """
  Parses API response data into a Space struct.

  ## Parameters
    - data - Map containing space data from API response

  ## Examples

      iex> Tama.Neural.Space.parse(%{"id" => "123", "name" => "My Space"})
      %Tama.Neural.Space{id: "123", name: "My Space"}

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
  Parses API response data into a Space struct, raising on error.
  """
  def parse!(attrs) do
    case parse(attrs) do
      %__MODULE__{} = space -> space
      _ -> raise "Failed to parse Space data"
    end
  end
end
