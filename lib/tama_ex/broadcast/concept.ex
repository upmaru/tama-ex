defmodule TamaEx.Broadcast.Concept do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :integer
    field :relation, :string
    field :content, :string
  end

  def changeset(concept, attrs) do
    concept
    |> cast(attrs, [:id, :relation, :content])
  end
end
