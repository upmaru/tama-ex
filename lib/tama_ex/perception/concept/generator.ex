defmodule TamaEx.Perception.Concept.Generator do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :type, Ecto.Enum, values: [:model, :module]
    field :reference, :string
    field :parameters, :map
  end

  def changeset(generator, attrs) do
    generator
    |> cast(attrs, [:type, :reference, :parameters])
    |> validate_required([:type, :reference, :parameters])
  end
end
