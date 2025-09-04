defmodule TamaEx.Broadcast.Chain do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :integer
    field :name, :string
  end

  def changeset(chain, attrs) do
    chain
    |> cast(attrs, [:id, :name])
  end
end
