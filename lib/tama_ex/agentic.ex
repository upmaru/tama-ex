defmodule TamaEx.Agentic do
  alias TamaEx.Message.Params, as: MessageParams

  def create_message(client, body, options \\ []) do
    with {:ok, validated_client} <- TamaEx.validate_client(client, ["agentic"]),
         {:ok, message_params} <- MessageParams.validate(body) do
      path = "/messages"
      timeout = Keyword.get(options, :timeout) || 300_000
      headers = Keyword.get(options, :headers) || []
      stream? = Keyword.get(options, :stream)

      callback =
        if stream? do
          Keyword.get(options, :callback)
        end

      if stream? && is_nil(callback) do
        raise """
        Stream handler is required when streaming is true pass a stream handler into options

        Example:

        fn {:data, data}, context ->
          Phoenix.PubSub.broadcast(YourApp.PubSub, "message:12", {:chunk, data})

          {:cont, context}
        end
        """
      end

      request =
        Req.merge(validated_client,
          method: :post,
          url: path,
          json: %{stream: stream?, message: message_params},
          receive_timeout: timeout,
          headers: headers
        )

      stream_handler = fn {:data, data}, context ->
        data
        |> handle_chunk()
        |> Enum.each(callback)

        {:cont, context}
      end

      request =
        if callback do
          Req.merge(request, into: stream_handler)
        else
          request
        end

      Req.request!(request)
    end
  end

  defp handle_chunk(data) do
    data
    |> String.split("data: ")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&decode/1)
    |> Enum.reject(&is_nil/1)
  end

  defp decode(""), do: nil
  defp decode("[DONE]"), do: nil
  defp decode(data), do: Jason.decode!(data)
end
