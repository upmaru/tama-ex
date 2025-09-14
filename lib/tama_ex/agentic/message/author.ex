defmodule TamaEx.Agentic.Message.Author do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :class, :string, default: "actor"
    field :identifier, :string
    field :source, :string
  end

  def changeset(author, attrs) do
    author
    |> cast(attrs, [:class, :identifier, :source])
    |> validate_required([:class, :identifier, :source])
  end
end
