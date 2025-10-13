defmodule TamaExTest do
  use ExUnit.Case
  doctest TamaEx

  defmodule TestSchema do
    def parse(data), do: %{parsed: data}
  end

  describe "client/4" do
    setup do
      bypass = Bypass.open()
      base_url = "http://localhost:#{bypass.port}"
      {:ok, bypass: bypass, base_url: base_url}
    end

    test "successfully authenticates and returns client with token", %{
      bypass: bypass,
      base_url: base_url
    } do
      client_id = "test_client_id"
      client_secret = "test_client_secret"

      # Mock the token response
      token_response = %{
        access_token: "access_token_123",
        token_type: "Bearer",
        scope: "provision.all",
        expires_in: 3600
      }

      Bypass.expect_once(bypass, "POST", "/auth/tokens", fn conn ->
        # Verify the request has correct authorization header
        auth_header = Enum.find(conn.req_headers, fn {key, _} -> key == "authorization" end)
        assert {"authorization", "Bearer " <> encoded_token} = auth_header

        # Verify the Basic auth token is correctly encoded
        expected_token = Base.url_encode64("#{client_id}:#{client_secret}", padding: false)
        assert encoded_token == expected_token

        # Verify the request body
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_json = Jason.decode!(body)
        assert body_json["grant_type"] == "client_credentials"
        assert body_json["scope"] == "provision.all"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(token_response))
      end)

      result = TamaEx.client(base_url, client_id, client_secret)

      assert {:ok, %{client: client, expires_in: 3600}} = result
      assert %Req.Request{} = client
      assert client.options[:base_url] == base_url

      # Verify the client has the bearer token in headers
      auth_header = Enum.find(client.headers, fn {key, _} -> key == "authorization" end)
      assert {"authorization", ["Bearer access_token_123"]} = auth_header
    end

    test "successfully authenticates with custom scopes", %{bypass: bypass, base_url: base_url} do
      client_id = "test_client_id"
      client_secret = "test_client_secret"
      custom_scopes = ["read", "write", "admin"]

      token_response = %{
        access_token: "access_token_456",
        token_type: "Bearer",
        scope: "read write admin",
        expires_in: 7200
      }

      Bypass.expect_once(bypass, "POST", "/auth/tokens", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_json = Jason.decode!(body)
        assert body_json["scope"] == "read write admin"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(token_response))
      end)

      result = TamaEx.client(base_url, client_id, client_secret, scopes: custom_scopes)

      assert {:ok, %{client: client, expires_in: 7200}} = result
      assert %Req.Request{} = client
    end

    test "returns error on authentication failure", %{bypass: bypass, base_url: base_url} do
      client_id = "invalid_client"
      client_secret = "invalid_secret"

      error_response = %{
        "error" => "invalid_client",
        "error_description" => "Client authentication failed"
      }

      Bypass.expect_once(bypass, "POST", "/auth/tokens", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(401, Jason.encode!(error_response))
      end)

      result = TamaEx.client(base_url, client_id, client_secret)

      assert {:error, ^error_response} = result
    end

    test "returns error on server error", %{bypass: bypass, base_url: base_url} do
      client_id = "test_client"
      client_secret = "test_secret"

      error_response = %{
        "error" => "server_error",
        "error_description" => "Internal server error"
      }

      Bypass.expect_once(bypass, "POST", "/auth/tokens", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(500, Jason.encode!(error_response))
      end)

      result = TamaEx.client(base_url, client_id, client_secret)

      assert {:error, ^error_response} = result
    end

    test "handles network errors gracefully", %{bypass: bypass} do
      # Close the bypass server to simulate network failure
      Bypass.down(bypass)

      base_url = "http://localhost:#{bypass.port}"
      result = TamaEx.client(base_url, "client_id", "client_secret")

      assert {:error, _reason} = result
    end

    test "uses default scopes when none provided", %{bypass: bypass, base_url: base_url} do
      client_id = "test_client_id"
      client_secret = "test_client_secret"

      token_response = %{
        access_token: "access_token_default",
        token_type: "Bearer",
        scope: "provision.all",
        expires_in: 3600
      }

      Bypass.expect_once(bypass, "POST", "/auth/tokens", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        body_json = Jason.decode!(body)
        # Should use default scope
        assert body_json["scope"] == "provision.all"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(token_response))
      end)

      result = TamaEx.client(base_url, client_id, client_secret)

      assert {:ok, %{client: _client, expires_in: 3600}} = result
    end
  end

  describe "put_namespace/2" do
    setup do
      bypass = Bypass.open()
      base_url = "http://localhost:#{bypass.port}"

      token_response = %{
        access_token: "test_token",
        token_type: "Bearer",
        scope: "provision.all",
        expires_in: 3600
      }

      Bypass.stub(bypass, "POST", "/auth/tokens", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(token_response))
      end)

      {:ok, bypass: bypass, base_url: base_url}
    end

    test "adds namespace to client base URL", %{base_url: base_url} do
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")

      namespaced_client = TamaEx.put_namespace(client, "provision")

      assert namespaced_client.options[:base_url] == "#{base_url}/provision"
    end

    test "adds multiple path segments as namespace", %{base_url: base_url} do
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")

      namespaced_client = TamaEx.put_namespace(client, "api/v1/provision")

      assert namespaced_client.options[:base_url] == "#{base_url}/api/v1/provision"
    end

    test "preserves other client options and headers", %{base_url: base_url} do
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")

      namespaced_client = TamaEx.put_namespace(client, "provision")

      # Should preserve headers
      assert namespaced_client.headers == client.headers

      # Should preserve other options except base_url
      original_options = Map.delete(client.options, :base_url)
      new_options = Map.delete(namespaced_client.options, :base_url)
      assert new_options == original_options
    end

    test "works with different namespace types", %{base_url: base_url} do
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")

      # Test different valid namespaces
      namespaces = ["provision", "ingest", "query", "agentic", "perception", "memory", "neural"]

      Enum.each(namespaces, fn namespace ->
        namespaced_client = TamaEx.put_namespace(client, namespace)
        assert namespaced_client.options[:base_url] == "#{base_url}/#{namespace}"
      end)
    end

    test "handles namespace with special characters", %{base_url: base_url} do
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")

      namespaced_client = TamaEx.put_namespace(client, "provision?version=v1")

      assert namespaced_client.options[:base_url] == "#{base_url}/provision?version=v1"
    end
  end

  describe "handle_response/2" do
    test "handles successful 200 response with data" do
      response = {:ok, %Req.Response{status: 200, body: %{"data" => %{"id" => "123"}}}}

      assert {:ok, %{parsed: %{"id" => "123"}}} = TamaEx.handle_response(response, TestSchema)
    end

    test "handles successful 201 response with data" do
      response = {:ok, %Req.Response{status: 201, body: %{"data" => %{"id" => "456"}}}}

      assert {:ok, %{parsed: %{"id" => "456"}}} = TamaEx.handle_response(response, TestSchema)
    end

    test "handles 404 not found response" do
      response = {:ok, %Req.Response{status: 404}}

      assert {:error, :not_found} = TamaEx.handle_response(response, TestSchema)
    end

    test "handles 422 validation error response" do
      errors = %{"name" => ["can't be blank"], "email" => ["is invalid"]}
      response = {:ok, %Req.Response{status: 422, body: %{"errors" => errors}}}

      assert {:error, {:validation_error, ^errors}} = TamaEx.handle_response(response, TestSchema)
    end

    test "handles generic HTTP errors with body" do
      response = {:ok, %Req.Response{status: 500, body: %{"message" => "Internal server error"}}}

      assert {:error, {:http_error, 500, %{"message" => "Internal server error"}}} =
               TamaEx.handle_response(response, TestSchema)
    end

    test "handles HTTP errors without body" do
      response = {:ok, %Req.Response{status: 503, body: ""}}

      assert {:error, {:http_error, 503, ""}} = TamaEx.handle_response(response, TestSchema)
    end

    test "handles request failure errors" do
      response = {:error, :timeout}

      assert {:error, {:request_failed, :timeout}} = TamaEx.handle_response(response, TestSchema)
    end

    test "handles network connection errors" do
      response = {:error, %{reason: :econnrefused}}

      assert {:error, {:request_failed, %{reason: :econnrefused}}} =
               TamaEx.handle_response(response, TestSchema)
    end
  end

  describe "validate_client/2" do
    setup do
      bypass = Bypass.open()
      base_url = "http://localhost:#{bypass.port}"

      # Setup a basic token response for client creation
      token_response = %{
        access_token: "test_token",
        token_type: "Bearer",
        scope: "provision.all",
        expires_in: 3600
      }

      Bypass.stub(bypass, "POST", "/auth/tokens", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(token_response))
      end)

      {:ok, bypass: bypass, base_url: base_url}
    end

    test "validates client with correct namespace", %{base_url: base_url} do
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")
      namespaced_client = TamaEx.put_namespace(client, "provision")

      assert {:ok, ^namespaced_client} = TamaEx.validate_client(namespaced_client, ["provision"])
    end

    test "validates client with multiple valid namespaces", %{base_url: base_url} do
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")
      namespaced_client = TamaEx.put_namespace(client, "ingest")

      assert {:ok, ^namespaced_client} =
               TamaEx.validate_client(namespaced_client, ["provision", "ingest", "query"])
    end

    test "raises error for invalid namespace", %{base_url: base_url} do
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")
      namespaced_client = TamaEx.put_namespace(client, "invalid")

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        TamaEx.validate_client(namespaced_client, ["provision"])
      end
    end

    test "raises error when no base_url is configured" do
      client = %Req.Request{options: %{}}

      assert_raise ArgumentError, ~r/Failed to extract namespace from client/, fn ->
        TamaEx.validate_client(client, ["provision"])
      end
    end

    test "raises error when base_url has no path", %{base_url: base_url} do
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")

      assert_raise ArgumentError, ~r/Failed to extract namespace from client/, fn ->
        TamaEx.validate_client(client, ["provision"])
      end
    end

    test "handles nested path namespaces correctly", %{base_url: base_url} do
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")
      namespaced_client = TamaEx.put_namespace(client, "v1/provision")

      assert {:ok, ^namespaced_client} = TamaEx.validate_client(namespaced_client, ["provision"])
    end

    test "error message includes expected and actual namespaces", %{base_url: base_url} do
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")
      namespaced_client = TamaEx.put_namespace(client, "wrong")

      error_message =
        try do
          TamaEx.validate_client(namespaced_client, ["provision", "ingest"])
        rescue
          e in ArgumentError -> e.message
        end

      assert error_message =~ "Expected one of [\"provision\", \"ingest\"]"
      assert error_message =~ "got 'wrong'"
    end

    test "handles complex URLs with query parameters", %{base_url: base_url} do
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")
      namespaced_client = TamaEx.put_namespace(client, "provision?version=v1")

      assert {:ok, ^namespaced_client} = TamaEx.validate_client(namespaced_client, ["provision"])
    end

    test "handles URLs with subdirectories", %{base_url: base_url} do
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")
      namespaced_client = TamaEx.put_namespace(client, "api/v1/provision")

      assert {:ok, ^namespaced_client} = TamaEx.validate_client(namespaced_client, ["provision"])
    end

    test "handles case-sensitive namespaces", %{base_url: base_url} do
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")
      namespaced_client = TamaEx.put_namespace(client, "Provision")

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        TamaEx.validate_client(namespaced_client, ["provision"])
      end
    end
  end

  describe "integration scenarios" do
    setup do
      bypass = Bypass.open()
      base_url = "http://localhost:#{bypass.port}"

      token_response = %{
        access_token: "integration_token",
        token_type: "Bearer",
        scope: "provision.all",
        expires_in: 3600
      }

      Bypass.stub(bypass, "POST", "/auth/tokens", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(token_response))
      end)

      {:ok, bypass: bypass, base_url: base_url}
    end

    test "typical API workflow with valid client", %{base_url: base_url} do
      # Create authenticated client
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")
      namespaced_client = TamaEx.put_namespace(client, "provision")

      # Validate client
      assert {:ok, validated_client} = TamaEx.validate_client(namespaced_client, ["provision"])
      assert validated_client == namespaced_client

      # Simulate successful response handling
      response = {:ok, %Req.Response{status: 200, body: %{"data" => %{"id" => "space-123"}}}}

      assert {:ok, %{parsed: %{"id" => "space-123"}}} =
               TamaEx.handle_response(response, TestSchema)
    end

    test "error handling workflow - invalid namespace", %{base_url: base_url} do
      # Create client with wrong namespace
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")
      namespaced_client = TamaEx.put_namespace(client, "wrong")

      # Should raise error during validation
      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        TamaEx.validate_client(namespaced_client, ["provision"])
      end
    end

    test "API error response workflow", %{base_url: base_url} do
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")
      namespaced_client = TamaEx.put_namespace(client, "provision")

      # Validate client successfully
      assert {:ok, _} = TamaEx.validate_client(namespaced_client, ["provision"])

      # Handle API error response
      error_response =
        {:ok, %Req.Response{status: 422, body: %{"errors" => %{"name" => ["required"]}}}}

      assert {:error, {:validation_error, %{"name" => ["required"]}}} =
               TamaEx.handle_response(error_response, TestSchema)
    end

    test "authentication failure workflow", %{bypass: bypass, base_url: base_url} do
      # Override the stub for this specific test
      Bypass.expect_once(bypass, "POST", "/auth/tokens", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(401, Jason.encode!(%{error: "invalid_client"}))
      end)

      result = TamaEx.client(base_url, "invalid_client", "invalid_secret")

      assert {:error, %{"error" => "invalid_client"}} = result
    end

    test "complete workflow with multiple validations", %{base_url: base_url} do
      # Test multiple different clients
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")
      provision_client = TamaEx.put_namespace(client, "provision")
      ingest_client = TamaEx.put_namespace(client, "ingest")

      # Both should validate for their respective namespaces
      assert {:ok, _} = TamaEx.validate_client(provision_client, ["provision"])
      assert {:ok, _} = TamaEx.validate_client(ingest_client, ["ingest"])

      # Cross-validation should fail
      assert_raise ArgumentError, fn ->
        TamaEx.validate_client(provision_client, ["ingest"])
      end
    end
  end

  describe "edge cases" do
    setup do
      bypass = Bypass.open()
      base_url = "http://localhost:#{bypass.port}"

      token_response = %{
        access_token: "edge_case_token",
        token_type: "Bearer",
        scope: "provision.all",
        expires_in: 3600
      }

      Bypass.stub(bypass, "POST", "/auth/tokens", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(token_response))
      end)

      {:ok, bypass: bypass, base_url: base_url}
    end

    test "handles URLs with fragment", %{base_url: base_url} do
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")
      namespaced_client = TamaEx.put_namespace(client, "provision#section")

      assert {:ok, ^namespaced_client} = TamaEx.validate_client(namespaced_client, ["provision"])
    end

    test "handles URLs with multiple path segments", %{base_url: base_url} do
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")
      namespaced_client = TamaEx.put_namespace(client, "v1/api/provision/endpoint")

      assert {:ok, ^namespaced_client} = TamaEx.validate_client(namespaced_client, ["endpoint"])
    end

    test "validates empty namespace list raises error", %{base_url: base_url} do
      {:ok, %{client: client}} = TamaEx.client(base_url, "client_id", "client_secret")
      namespaced_client = TamaEx.put_namespace(client, "provision")

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        TamaEx.validate_client(namespaced_client, [])
      end
    end

    test "handles special characters in credentials", %{bypass: bypass, base_url: base_url} do
      client_id = "client@domain.com"
      client_secret = "p@ssw0rd!#$%"

      token_response = %{
        access_token: "special_char_token",
        token_type: "Bearer",
        scope: "provision.all",
        expires_in: 3600
      }

      Bypass.expect_once(bypass, "POST", "/auth/tokens", fn conn ->
        # Verify the Basic auth token handles special characters correctly
        auth_header = Enum.find(conn.req_headers, fn {key, _} -> key == "authorization" end)
        assert {"authorization", "Bearer " <> encoded_token} = auth_header

        expected_token = Base.url_encode64("#{client_id}:#{client_secret}", padding: false)
        assert encoded_token == expected_token

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(token_response))
      end)

      result = TamaEx.client(base_url, client_id, client_secret)

      assert {:ok, %{client: _client, expires_in: 3600}} = result
    end
  end
end
