defmodule TamaEx.Broadcast.Metadata do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :changes, :map
    field :comment, :string
    field :parameters, :map
  end

  def changeset(metadata, attrs) do
    metadata
    |> cast(attrs, [:changes, :comment, :parameters])
  end
end
