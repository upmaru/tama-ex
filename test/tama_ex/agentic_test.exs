defmodule TamaEx.AgenticTest do
  use ExUnit.Case
  doctest TamaEx.Agentic

  alias TamaEx.Agentic

  setup do
    bypass = Bypass.open()
    client = TamaEx.client(base_url: "http://localhost:#{bypass.port}/agentic")

    {:ok, bypass: bypass, client: client}
  end

  describe "create_message/3 - client validation" do
    test "validates required client namespace", %{client: _client} do
      # Test with wrong namespace
      client = TamaEx.client(base_url: "https://api.example.com/provision")

      body = %{
        "recipient" => "user-123",
        "content" => "Hello, world!",
        "author" => %{
          "identifier" => "agent-1",
          "source" => "system"
        },
        "thread" => %{
          "identifier" => "thread-456"
        },
        "identifier" => "msg-789",
        "index" => 1
      }

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        Agentic.create_message(client, body)
      end
    end

    test "handles client validation errors" do
      # Test client without base_url
      invalid_client = %Req.Request{options: %{}}

      body = %{
        "recipient" => "user-123",
        "content" => "Hello, world!"
      }

      assert_raise ArgumentError, ~r/Failed to extract namespace/, fn ->
        Agentic.create_message(invalid_client, body)
      end
    end
  end

  describe "create_message/3 - message validation" do
    test "handles invalid message params", %{client: client} do
      # Test with missing required fields
      invalid_body = %{
        "content" => "Hello, world!"
        # Missing required fields like recipient, author, thread, etc.
      }

      assert_raise Ecto.InvalidChangesetError, fn ->
        Agentic.create_message(client, invalid_body)
      end
    end

    test "validates message structure with missing author", %{client: client} do
      invalid_body = %{
        "recipient" => "user-123",
        "content" => "Hello, world!",
        "identifier" => "msg-789",
        "index" => 1
        # Missing author and thread
      }

      assert_raise Ecto.InvalidChangesetError, fn ->
        Agentic.create_message(client, invalid_body)
      end
    end
  end

  describe "create_message/3 - non-streaming requests" do
    test "handles successful non-streaming response", %{bypass: bypass, client: client} do
      Bypass.expect(bypass, "POST", "/agentic/messages", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request_data = Jason.decode!(body)

        assert request_data["message"]["recipient"] == "user-123"
        assert request_data["message"]["content"] == "Hello, world!"
        assert request_data["message"]["author"]["identifier"] == "agent-1"
        assert request_data["message"]["thread"]["identifier"] == "thread-456"

        response_data = %{
          id: "msg-response-123",
          status: "sent",
          message: %{
            recipient: "user-123",
            content: "Hello, world!",
            author: %{
              identifier: "agent-1",
              source: "system",
              class: "actor"
            },
            thread: %{
              identifier: "thread-456",
              class: "thread"
            },
            identifier: "msg-789",
            index: 1,
            class: "user-message"
          }
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response_data))
      end)

      body = %{
        "recipient" => "user-123",
        "content" => "Hello, world!",
        "author" => %{
          "identifier" => "agent-1",
          "source" => "system"
        },
        "thread" => %{
          "identifier" => "thread-456"
        },
        "identifier" => "msg-789",
        "index" => 1
      }

      response = Agentic.create_message(client, body)

      assert %Req.Response{status: 200, body: response_body} = response
      assert response_body["id"] == "msg-response-123"
      assert response_body["status"] == "sent"
      assert response_body["message"]["recipient"] == "user-123"
      assert response_body["message"]["content"] == "Hello, world!"
    end

    test "handles non-streaming request with custom options", %{bypass: bypass, client: client} do
      Bypass.expect(bypass, "POST", "/agentic/messages", fn conn ->
        # Check headers
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-token"]
        assert Plug.Conn.get_req_header(conn, "custom-header") == ["test-value"]

        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request_data = Jason.decode!(body)

        assert request_data["message"]["recipient"] == "user-456"

        response_data = %{
          id: "msg-custom-789",
          status: "delivered",
          message: %{
            recipient: "user-456",
            content: "Custom message"
          }
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response_data))
      end)

      body = %{
        "recipient" => "user-456",
        "content" => "Custom message",
        "author" => %{
          "identifier" => "agent-2",
          "source" => "system"
        },
        "thread" => %{
          "identifier" => "thread-custom"
        },
        "identifier" => "msg-custom",
        "index" => 1
      }

      options = [
        timeout: 60_000,
        headers: [
          {"Authorization", "Bearer test-token"},
          {"Custom-Header", "test-value"}
        ]
      ]

      response = Agentic.create_message(client, body, options)

      assert %Req.Response{status: 200, body: response_body} = response
      assert response_body["id"] == "msg-custom-789"
      assert response_body["status"] == "delivered"
    end
  end

  describe "create_message/3 - streaming requests" do
    test "raises error when stream is true but no callback provided", %{client: client} do
      body = %{
        "recipient" => "user-123",
        "content" => "Hello, streaming world!",
        "author" => %{
          "identifier" => "agent-1",
          "source" => "system"
        },
        "thread" => %{
          "identifier" => "thread-456"
        },
        "identifier" => "msg-stream",
        "index" => 1,
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
        Agentic.create_message(client, body)
      end
    end

    test "handles streaming response with callback", %{bypass: bypass, client: client} do
      test_pid = self()

      Bypass.expect(bypass, "POST", "/agentic/messages", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request_data = Jason.decode!(body)

        assert request_data["message"]["stream"] == true

        conn =
          conn
          |> Plug.Conn.put_resp_content_type("text/event-stream")
          |> Plug.Conn.put_resp_header("cache-control", "no-cache")
          |> Plug.Conn.put_resp_header("connection", "keep-alive")
          |> Plug.Conn.send_chunked(200)

        {:ok, conn} =
          Plug.Conn.chunk(
            conn,
            "data: #{Jason.encode!(%{id: "msg-stream-123", type: "message.start", message: %{recipient: "user-123", status: "processing"}})}\n\n"
          )

        {:ok, conn} =
          Plug.Conn.chunk(
            conn,
            "data: #{Jason.encode!(%{id: "msg-stream-123", type: "content.delta", delta: %{content: "Hello"}})}\n\n"
          )

        {:ok, conn} =
          Plug.Conn.chunk(
            conn,
            "data: #{Jason.encode!(%{id: "msg-stream-123", type: "content.delta", delta: %{content: " streaming"}})}\n\n"
          )

        {:ok, conn} =
          Plug.Conn.chunk(
            conn,
            "data: #{Jason.encode!(%{id: "msg-stream-123", type: "content.delta", delta: %{content: " world!"}})}\n\n"
          )

        {:ok, conn} =
          Plug.Conn.chunk(
            conn,
            "data: #{Jason.encode!(%{id: "msg-stream-123", type: "message.complete", message: %{status: "sent", final_content: "Hello streaming world!"}})}\n\n"
          )

        {:ok, conn} = Plug.Conn.chunk(conn, "data: [DONE]\n\n")

        conn
      end)

      callback = fn data ->
        send(test_pid, {:chunk_received, data})
      end

      body = %{
        "recipient" => "user-123",
        "content" => "Hello, streaming world!",
        "author" => %{
          "identifier" => "agent-1",
          "source" => "system"
        },
        "thread" => %{
          "identifier" => "thread-456"
        },
        "identifier" => "msg-stream",
        "index" => 1,
        "stream" => true
      }

      options = [callback: callback]

      response = Agentic.create_message(client, body, options)

      # Verify response structure
      assert %Req.Response{status: 200} = response

      # Collect all received chunks
      # Expecting 5 chunks (excluding [DONE])
      chunks = collect_chunks([], 5)

      # Verify we received the expected chunks
      assert length(chunks) == 5

      # Check first chunk (message start)
      first_chunk = List.first(chunks)
      assert first_chunk["id"] == "msg-stream-123"
      assert first_chunk["type"] == "message.start"
      assert first_chunk["message"]["recipient"] == "user-123"
      assert first_chunk["message"]["status"] == "processing"

      # Check content delta chunks
      content_chunks = Enum.slice(chunks, 1, 3)

      contents =
        Enum.map(content_chunks, fn chunk ->
          chunk["delta"]["content"]
        end)

      assert contents == ["Hello", " streaming", " world!"]

      # Check final chunk (message complete)
      final_chunk = List.last(chunks)
      assert final_chunk["type"] == "message.complete"
      assert final_chunk["message"]["status"] == "sent"
      assert final_chunk["message"]["final_content"] == "Hello streaming world!"
    end

    test "handles streaming with atom keys in body", %{bypass: bypass, client: client} do
      test_pid = self()

      Bypass.expect(bypass, "POST", "/agentic/messages", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request_data = Jason.decode!(body)

        assert request_data["message"]["stream"] == true

        conn =
          conn
          |> Plug.Conn.put_resp_content_type("text/event-stream")
          |> Plug.Conn.send_chunked(200)

        {:ok, conn} =
          Plug.Conn.chunk(
            conn,
            "data: #{Jason.encode!(%{id: "test-atom-123", type: "content.delta", delta: %{content: "Atom test"}})}\n\n"
          )

        {:ok, conn} = Plug.Conn.chunk(conn, "data: [DONE]\n\n")

        conn
      end)

      callback = fn data ->
        send(test_pid, {:chunk_received, data})
      end

      body = %{
        recipient: "user-atom",
        content: "Atom keys test",
        author: %{
          identifier: "agent-atom",
          source: "system"
        },
        thread: %{
          identifier: "thread-atom"
        },
        identifier: "msg-atom",
        index: 1,
        stream: true
      }

      options = [callback: callback]

      response = Agentic.create_message(client, body, options)

      assert %Req.Response{status: 200} = response

      # Verify we get the chunk
      assert_receive {:chunk_received, chunk_data}
      assert chunk_data["id"] == "test-atom-123"
      assert chunk_data["type"] == "content.delta"
      assert chunk_data["delta"]["content"] == "Atom test"
    end
  end

  describe "data parsing functionality" do
    test "handles mixed streaming data formats", %{bypass: bypass, client: client} do
      test_pid = self()

      Bypass.expect(bypass, "POST", "/agentic/messages", fn conn ->
        conn =
          conn
          |> Plug.Conn.put_resp_content_type("text/event-stream")
          |> Plug.Conn.send_chunked(200)

        # Test various data formats that should be handled
        {:ok, conn} =
          Plug.Conn.chunk(conn, "data: #{Jason.encode!(%{test: "valid_json", type: "test"})}\n\n")

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
        "recipient" => "user-mixed",
        "content" => "Mixed data test",
        "author" => %{
          "identifier" => "agent-mixed",
          "source" => "system"
        },
        "thread" => %{
          "identifier" => "thread-mixed"
        },
        "identifier" => "msg-mixed",
        "index" => 1,
        "stream" => true
      }

      options = [callback: callback]

      _response = Agentic.create_message(client, body, options)

      # Should only receive the valid JSON chunk, empty data and [DONE] should be filtered
      assert_receive {:chunk_received, chunk_data}
      assert chunk_data["test"] == "valid_json"
      assert chunk_data["type"] == "test"

      # Should not receive any more chunks (empty and [DONE] filtered out)
      refute_receive {:chunk_received, _}
    end
  end

  describe "timeout handling" do
    test "uses default timeout when not specified", %{bypass: bypass, client: client} do
      # We can't directly test the timeout value, but we can verify the request is made
      Bypass.expect(bypass, "POST", "/agentic/messages", fn conn ->
        # Simulate a request that would benefit from long timeout
        # Small delay to simulate processing
        Process.sleep(100)

        response_data = %{
          id: "timeout-test-123",
          status: "sent"
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response_data))
      end)

      body = %{
        "recipient" => "timeout-user",
        "content" => "Timeout test",
        "author" => %{
          "identifier" => "timeout-agent",
          "source" => "system"
        },
        "thread" => %{
          "identifier" => "timeout-thread"
        },
        "identifier" => "timeout-msg",
        "index" => 1
      }

      response = Agentic.create_message(client, body)

      assert %Req.Response{status: 200, body: response_body} = response
      assert response_body["id"] == "timeout-test-123"
    end

    test "uses custom timeout when specified", %{bypass: bypass, client: client} do
      Bypass.expect(bypass, "POST", "/agentic/messages", fn conn ->
        response_data = %{
          id: "custom-timeout-456",
          status: "sent"
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response_data))
      end)

      body = %{
        "recipient" => "custom-timeout-user",
        "content" => "Custom timeout test",
        "author" => %{
          "identifier" => "custom-timeout-agent",
          "source" => "system"
        },
        "thread" => %{
          "identifier" => "custom-timeout-thread"
        },
        "identifier" => "custom-timeout-msg",
        "index" => 1
      }

      # 2 minutes
      options = [timeout: 120_000]

      response = Agentic.create_message(client, body, options)

      assert %Req.Response{status: 200, body: response_body} = response
      assert response_body["id"] == "custom-timeout-456"
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
