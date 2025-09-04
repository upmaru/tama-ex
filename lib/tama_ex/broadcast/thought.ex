defmodule TamaEx.Broadcast.Thought do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :relation, :string
    field :index, :integer
    embeds_one :chain, TamaEx.Broadcast.Chain
  end

  def changeset(thought, attrs) do
    thought
    |> cast(attrs, [:relation, :index])
    |> cast_embed(:chain)
  end
end
