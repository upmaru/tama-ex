defmodule TamaEx.Broadcast.OriginEntity do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :binary_id
    field :current_state, :string
    field :identifier, :string
  end

  def changeset(origin_entity, attrs) do
    origin_entity
    |> cast(attrs, [:id, :current_state, :identifier])
  end
end
