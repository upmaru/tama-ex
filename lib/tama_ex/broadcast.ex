defmodule TamaEx.Broadcast do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    embeds_one :event, TamaEx.Broadcast.Event
    embeds_one :step, TamaEx.Broadcast.Step
  end

  def changeset(broadcast, attrs) do
    broadcast
    |> cast(attrs, [])
    |> cast_embed(:event, required: true)
    |> cast_embed(:step, required: true)
  end

  def parse(params) do
    %__MODULE__{}
    |> changeset(params)
    |> apply_action(:insert)
  end
end
