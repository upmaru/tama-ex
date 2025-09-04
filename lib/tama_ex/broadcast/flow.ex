defmodule TamaEx.Broadcast.Flow do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :integer
    embeds_one :origin_entity, TamaEx.Broadcast.OriginEntity
  end

  def changeset(flow, attrs) do
    flow
    |> cast(attrs, [:id])
    |> cast_embed(:origin_entity)
  end
end
