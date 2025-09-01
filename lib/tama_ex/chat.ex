defmodule TamaEx.Chat do
  alias __MODULE__.Response

  defdelegate create_response(client, body, options \\ []), to: Response, as: :create
end
