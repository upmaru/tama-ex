defmodule TamaEx.Messaging.ResponseTest do
  use ExUnit.Case
  doctest TamaEx.Messaging.Response

  alias TamaEx.Messaging.Response

  setup do
    bypass = Bypass.open()
    client = TamaEx.client(base_url: "http://localhost:#{bypass.port}/api")

    {:ok, bypass: bypass, client: client}
  end

  describe "create/3 - client validation" do
    test "validates required client namespace", %{client: _client} do
      # Test with wrong namespace
      client = TamaEx.client(base_url: "https://api.example.com/provision")

      body = %{
        "model" => "gpt-4",
        "messages" => [%{"role" => "user", "content" => "Hello"}]
      }

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        Response.create(client, body)
      end
    end

    test "handles client validation errors" do
      # Test client without base_url
      invalid_client = %Req.Request{options: %{}}

      body = %{
        "model" => "gpt-4",
        "messages" => [%{"role" => "user", "content" => "Hello"}]
      }

      assert_raise ArgumentError, ~r/Failed to extract namespace/, fn ->
        Response.create(invalid_client, body)
      end
    end
  end

  describe "create/3 - non-streaming requests" do
    test "handles successful non-streaming response", %{bypass: bypass, client: client} do
      Bypass.expect(bypass, "POST", "/api/chat/completions", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request_data = Jason.decode!(body)

        assert request_data["model"] == "gpt-4"
        assert request_data["messages"] == [%{"role" => "user", "content" => "Hello"}]

        response_data = %{
          id: "chatcmpl-123",
          object: "chat.completion",
          created: 1_694_268_190,
          model: "gpt-4",
          choices: [
            %{
              index: 0,
              message: %{
                role: "assistant",
                content: "Hello! How can I help you today?"
              },
              finish_reason: "stop"
            }
          ],
          usage: %{
            prompt_tokens: 10,
            completion_tokens: 9,
            total_tokens: 19
          }
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response_data))
      end)

      body = %{
        "model" => "gpt-4",
        "messages" => [%{"role" => "user", "content" => "Hello"}]
      }

      response = Response.create(client, body)

      assert %Req.Response{status: 200, body: response_body} = response
      assert response_body["id"] == "chatcmpl-123"

      assert response_body["choices"] |> List.first() |> get_in(["message", "content"]) ==
               "Hello! How can I help you today?"
    end

    test "handles non-streaming request with custom options", %{bypass: bypass, client: client} do
      Bypass.expect(bypass, "POST", "/api/chat/completions", fn conn ->
        # Check headers
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]
        assert Plug.Conn.get_req_header(conn, "custom-header") == ["test-value"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request_data = Jason.decode!(body)

        assert request_data["model"] == "gpt-4"

        response_data = %{
          id: "chatcmpl-456",
          object: "chat.completion",
          model: "gpt-4"
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response_data))
      end)

      body = %{
        "model" => "gpt-4",
        "messages" => [%{"role" => "user", "content" => "Hello"}]
      }

      options = [
        timeout: 60_000,
        headers: [
          {"Authorization", "Bearer test-token"},
          {"Custom-Header", "test-value"}
        ]
      ]

      response = Response.create(client, body, options)

      assert %Req.Response{status: 200, body: response_body} = response
      assert response_body["id"] == "chatcmpl-456"
    end
  end

  describe "create/3 - streaming requests" do
    test "raises error when stream is true but no callback provided", %{client: client} do
      body = %{
        "model" => "gpt-4",
        "messages" => [%{"role" => "user", "content" => "Hello"}],
        "stream" => true
      }

      expected_message = """
      Stream handler is required when streaming is true pass a stream handler into options

      Example:

      fn {:data, data}, context ->
        Phoenix.PubSub.broadcast(YourApp.PubSub, "message:12", {:chunk, data})

        {:cont, context}
      end
      """

      assert_raise RuntimeError, expected_message, fn ->
        Response.create(client, body)
      end
    end

    test "handles streaming response with callback", %{bypass: bypass, client: client} do
      test_pid = self()

      Bypass.expect(bypass, "POST", "/api/chat/completions", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request_data = Jason.decode!(body)

        assert request_data["stream"] == true

        conn =
          conn
          |> Plug.Conn.put_resp_content_type("text/event-stream")
          |> Plug.Conn.put_resp_header("cache-control", "no-cache")
          |> Plug.Conn.put_resp_header("connection", "keep-alive")
          |> Plug.Conn.send_chunked(200)

        {:ok, conn} =
          Plug.Conn.chunk(
            conn,
            "data: #{Jason.encode!(%{id: "chatcmpl-123", object: "chat.completion.chunk", created: 1_694_268_190, model: "gpt-3.5-turbo", choices: [%{index: 0, delta: %{role: "assistant"}, finish_reason: nil}]})}\n\n"
          )

        {:ok, conn} =
          Plug.Conn.chunk(
            conn,
            "data: #{Jason.encode!(%{id: "chatcmpl-123", object: "chat.completion.chunk", created: 1_694_268_190, model: "gpt-3.5-turbo", choices: [%{index: 0, delta: %{content: "Hello"}, finish_reason: nil}]})}\n\n"
          )

        {:ok, conn} =
          Plug.Conn.chunk(
            conn,
            "data: #{Jason.encode!(%{id: "chatcmpl-123", object: "chat.completion.chunk", created: 1_694_268_190, model: "gpt-3.5-turbo", choices: [%{index: 0, delta: %{content: " how"}, finish_reason: nil}]})}\n\n"
          )

        {:ok, conn} =
          Plug.Conn.chunk(
            conn,
            "data: #{Jason.encode!(%{id: "chatcmpl-123", object: "chat.completion.chunk", created: 1_694_268_190, model: "gpt-3.5-turbo", choices: [%{index: 0, delta: %{content: " are"}, finish_reason: nil}]})}\n\n"
          )

        {:ok, conn} =
          Plug.Conn.chunk(
            conn,
            "data: #{Jason.encode!(%{id: "chatcmpl-123", object: "chat.completion.chunk", created: 1_694_268_190, model: "gpt-3.5-turbo", choices: [%{index: 0, delta: %{content: " you?"}, finish_reason: nil}]})}\n\n"
          )

        {:ok, conn} =
          Plug.Conn.chunk(
            conn,
            "data: #{Jason.encode!(%{id: "chatcmpl-123", object: "chat.completion.chunk", created: 1_694_268_190, model: "gpt-3.5-turbo", choices: [%{index: 0, delta: %{}, finish_reason: "stop"}]})}\n\n"
          )

        {:ok, conn} = Plug.Conn.chunk(conn, "data: [DONE]\n\n")

        conn
      end)

      callback = fn data ->
        send(test_pid, {:chunk_received, data})
      end

      body = %{
        "model" => "gpt-3.5-turbo",
        "messages" => [%{"role" => "user", "content" => "Hello"}],
        "stream" => true
      }

      options = [callback: callback]

      response = Response.create(client, body, options)

      # Verify response structure
      assert %Req.Response{status: 200} = response

      # Collect all received chunks
      # Expecting 6 chunks (excluding [DONE])
      chunks = collect_chunks([], 6)

      # Verify we received the expected chunks
      assert length(chunks) == 6

      # Check first chunk (role assignment)
      first_chunk = List.first(chunks)
      assert first_chunk["id"] == "chatcmpl-123"
      assert first_chunk["choices"] |> List.first() |> get_in(["delta", "role"]) == "assistant"

      # Check content chunks
      content_chunks = Enum.drop(chunks, 1) |> Enum.take(4)

      contents =
        Enum.map(content_chunks, fn chunk ->
          chunk["choices"] |> List.first() |> get_in(["delta", "content"])
        end)

      assert contents == ["Hello", " how", " are", " you?"]

      # Check final chunk (finish reason)
      final_chunk = List.last(chunks)
      assert final_chunk["choices"] |> List.first() |> get_in(["finish_reason"]) == "stop"
    end

    test "handles streaming with atom keys in body", %{bypass: bypass, client: client} do
      test_pid = self()

      Bypass.expect(bypass, "POST", "/api/chat/completions", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request_data = Jason.decode!(body)

        assert request_data["stream"] == true

        conn =
          conn
          |> Plug.Conn.put_resp_content_type("text/event-stream")
          |> Plug.Conn.send_chunked(200)

        {:ok, conn} =
          Plug.Conn.chunk(
            conn,
            "data: #{Jason.encode!(%{id: "test-123", choices: [%{delta: %{content: "Test"}}]})}\n\n"
          )

        {:ok, conn} = Plug.Conn.chunk(conn, "data: [DONE]\n\n")

        conn
      end)

      callback = fn data ->
        send(test_pid, {:chunk_received, data})
      end

      body = %{
        model: "gpt-4",
        messages: [%{role: "user", content: "Hello"}],
        stream: true
      }

      options = [callback: callback]

      response = Response.create(client, body, options)

      assert %Req.Response{status: 200} = response

      # Verify we get the chunk
      assert_receive {:chunk_received, chunk_data}
      assert chunk_data["id"] == "test-123"
      assert chunk_data["choices"] |> List.first() |> get_in(["delta", "content"]) == "Test"
    end
  end

  describe "data parsing functionality" do
    test "handles mixed streaming data formats", %{bypass: bypass, client: client} do
      test_pid = self()

      Bypass.expect(bypass, "POST", "/api/chat/completions", fn conn ->
        conn =
          conn
          |> Plug.Conn.put_resp_content_type("text/event-stream")
          |> Plug.Conn.send_chunked(200)

        # Test various data formats that should be handled
        {:ok, conn} = Plug.Conn.chunk(conn, "data: #{Jason.encode!(%{test: "valid_json"})}\n\n")
        # Empty data - should be filtered
        {:ok, conn} = Plug.Conn.chunk(conn, "data: \n\n")
        # Should be filtered
        {:ok, conn} = Plug.Conn.chunk(conn, "data: [DONE]\n\n")

        conn
      end)

      callback = fn data ->
        send(test_pid, {:chunk_received, data})
      end

      body = %{
        "model" => "gpt-4",
        "messages" => [%{"role" => "user", "content" => "Test"}],
        "stream" => true
      }

      options = [callback: callback]

      _response = Response.create(client, body, options)

      # Should only receive the valid JSON chunk, empty data and [DONE] should be filtered
      assert_receive {:chunk_received, chunk_data}
      assert chunk_data["test"] == "valid_json"

      # Should not receive any more chunks (empty and [DONE] filtered out)
      refute_receive {:chunk_received, _}
    end
  end

  # Helper function to collect streaming chunks
  defp collect_chunks(chunks, 0), do: Enum.reverse(chunks)

  defp collect_chunks(chunks, remaining) do
    receive do
      {:chunk_received, chunk} ->
        collect_chunks([chunk | chunks], remaining - 1)
    after
      1000 ->
        # Return what we have if we timeout
        Enum.reverse(chunks)
    end
  end
end
