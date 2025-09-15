defmodule TamaEx.Message.Params do
  use Ecto.Schema
  import Ecto.Changeset

  @derive Jason.Encoder

  alias TamaEx.Message.Params.Author
  alias TamaEx.Message.Params.Thread

  @valid_attrs [
    :recipient,
    :class,
    :identifier,
    :content,
    :index,
    :stream
  ]

  @primary_key false
  embedded_schema do
    field :recipient, :string
    field :class, :string, default: "user-message"
    field :identifier, :string
    field :content, :string
    field :index, :integer
    field :stream, :boolean, default: false

    embeds_one :author, Author
    embeds_one :thread, Thread
  end

  def changeset(params, attrs) do
    params
    |> cast(attrs, @valid_attrs)
    |> validate_required([:recipient, :identifier, :content, :index])
    |> cast_embed(:author, required: true)
    |> cast_embed(:thread, required: true)
  end

  def validate(attrs) when is_map(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> case do
      %Ecto.Changeset{valid?: true} = changeset ->
        {:ok, apply_changes(changeset)}

      %Ecto.Changeset{valid?: false} = changeset ->
        raise Ecto.InvalidChangesetError, action: :validate, changeset: changeset
    end
  end
end
