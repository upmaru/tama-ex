defmodule TamaEx.Agentic.Message.Thread do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :class, :string, default: "thread"
    field :identifier, :string
  end

  def changeset(thread, attrs) do
    thread
    |> cast(attrs, [:class, :thread])
    |> validate_required([:class, :thread])
  end
end
