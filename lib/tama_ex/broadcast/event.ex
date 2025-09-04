defmodule TamaEx.Broadcast.Event do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :name, :string
    field :domain, :string
    embeds_one :metadata, TamaEx.Broadcast.Metadata
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:name, :domain])
    |> cast_embed(:metadata)
  end
end
