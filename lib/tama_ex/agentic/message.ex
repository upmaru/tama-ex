defmodule TamaEx.Agentic.Message do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :binary_id
    field :identifier, :string
    field :current_state, :string
  end

  def changeset(message, attrs) do
    message
    |> cast(attrs, [:id, :identifier, :current_state])
    |> validate_required([:id, :identifier, :current_state])
  end

  def parse!(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action!(:insert)
  end
end
