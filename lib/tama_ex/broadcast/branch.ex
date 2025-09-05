defmodule TamaEx.Broadcast.Branch do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :binary_id
    field :chain_id, :binary_id
    field :current_state, :string
    embeds_one :flow, TamaEx.Broadcast.Flow
  end

  def changeset(branch, attrs) do
    branch
    |> cast(attrs, [:id, :chain_id, :current_state])
    |> cast_embed(:flow)
  end
end
