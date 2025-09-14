defmodule TamaEx.Agentic.Message.Params do
  use Ecto.Schema
  import Ecto.Changeset

  alias TamaEx.Agentic.Message.Author
  alias TamaEx.Agentic.Message.Thread

  @primary_key false
  embedded_schema do
    field :recipient, :string
    field :class, :string, default: "user-message"
    field :identifier, :string

    embeds_one :author, Author
    embeds_one :thread, Thread

    field :content, :string
    field :index, :integer
  end

  def changeset(params, attrs) do
    params
    |> cast(attrs, [:recipient, :class, :identifier, :content, :index])
    |> validate_required([:recipient, :class, :identifier, :content, :index])
    |> cast_embed(:author, required: true)
    |> cast_embed(:thread, required: true)
  end
end
