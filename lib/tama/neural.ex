defmodule TamaEx.Neural do
  @moduledoc """
  Client for interacting with Neural API endpoints.
  """

  alias __MODULE__.Space

  @doc """
  Gets a space by slug from the provision endpoint.

  ## Parameters
    - :provision - The endpoint type (currently only :provision is supported)
    - slug - The slug identifier for the space

  ## Examples

      iex> Tama.Neural.get_space(client, "my-space")
      {:ok, %Tama.Neural.Space{}}

      iex> Tama.Neural.get_space(client, "nonexistent")
      {:error, :not_found}

  """
  def get_space(client, slug) when is_binary(slug) do
    url = "/neural/spaces/#{slug}"

    client
    |> Req.get(url: url)
    |> TamaEx.handle_response(Space)
  end

  alias __MODULE__.Class

  def get_class(client, %Space{id: space_id}, name) when is_binary(name) do
    url = "/neural/spaces/#{space_id}/classes/#{name}"

    client
    |> Req.get(url: url)
    |> TamaEx.handle_response(Class)
  end
end
