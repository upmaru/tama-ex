defmodule TamaEx.Agentic.Message.Params do
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder

  alias TamaEx.Agentic.Message.Author
  alias TamaEx.Agentic.Message.Thread

  @valid_attrs [
    :recipient,
    :class,
    :identifier,
    :content,
    :index
  ]

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
    |> cast(attrs, @valid_attrs)
    |> validate_required(@valid_attrs)
    |> cast_embed(:author, required: true)
    |> cast_embed(:thread, required: true)
  end
end
