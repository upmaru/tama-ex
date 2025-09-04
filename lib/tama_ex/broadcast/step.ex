defmodule TamaEx.Broadcast.Step do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :integer
    field :current_state, :string
    field :index, :integer
    field :attempt, :integer
    embeds_many :concepts, TamaEx.Broadcast.Concept
    embeds_one :thought, TamaEx.Broadcast.Thought
    embeds_one :branch, TamaEx.Broadcast.Branch
  end

  def changeset(step, attrs) do
    step
    |> cast(attrs, [:id, :current_state, :index, :attempt])
    |> cast_embed(:concepts)
    |> cast_embed(:thought)
    |> cast_embed(:branch)
  end
end
