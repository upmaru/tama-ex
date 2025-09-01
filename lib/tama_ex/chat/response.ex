defmodule TamaEx.Chat.Response do
  def create(client, body, options \\ []) do
    with {:ok, validated_client} <- TamaEx.validate_client(client, ["api"]) do
      path = "/chat/completions"
      timeout = Keyword.get(options, :timeout) || 300_000
      headers = Keyword.get(options, :headers) || []
      stream? = Map.get(body, "stream") || Map.get(body, :stream)

      stream_handler =
        if stream? do
          Keyword.get(options, :stream)
        end

      if stream? && is_nil(stream_handler) do
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
          json: body,
          receive_timeout: timeout,
          headers: headers
        )

      request =
        if stream_handler do
          Req.merge(request, into: stream_handler)
        else
          request
        end

      Req.request!(request)
    end
  end
end
