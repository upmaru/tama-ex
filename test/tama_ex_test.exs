defmodule TamaExTest do
  use ExUnit.Case
  doctest TamaEx

  defmodule TestSchema do
    def parse(data), do: %{parsed: data}
  end

  describe "client/1" do
    test "creates a new HTTP client with base URL" do
      base_url = "https://api.example.com"
      client = TamaEx.client(base_url: base_url)

      assert %Req.Request{} = client
      assert client.options[:base_url] == base_url
    end

    test "accepts different base URLs" do
      provision_client = TamaEx.client(base_url: "https://api.example.com/provision")
      ingest_client = TamaEx.client(base_url: "https://api.example.com/ingest")

      assert provision_client.options[:base_url] == "https://api.example.com/provision"
      assert ingest_client.options[:base_url] == "https://api.example.com/ingest"
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
    test "validates client with correct namespace" do
      client = TamaEx.client(base_url: "https://api.example.com/provision")

      assert {:ok, ^client} = TamaEx.validate_client(client, ["provision"])
    end

    test "validates client with multiple valid namespaces" do
      client = TamaEx.client(base_url: "https://api.example.com/ingest")

      assert {:ok, ^client} = TamaEx.validate_client(client, ["provision", "ingest", "query"])
    end

    test "raises error for invalid namespace" do
      client = TamaEx.client(base_url: "https://api.example.com/invalid")

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        TamaEx.validate_client(client, ["provision"])
      end
    end

    test "raises error when no base_url is configured" do
      client = %Req.Request{options: %{}}

      assert_raise ArgumentError, ~r/Failed to extract namespace from client/, fn ->
        TamaEx.validate_client(client, ["provision"])
      end
    end

    test "raises error when base_url has no path" do
      client = TamaEx.client(base_url: "https://api.example.com")

      assert_raise ArgumentError, ~r/Failed to extract namespace from client/, fn ->
        TamaEx.validate_client(client, ["provision"])
      end
    end

    test "raises error when base_url has empty path" do
      client = TamaEx.client(base_url: "https://api.example.com/")

      assert_raise ArgumentError, ~r/Failed to extract namespace from client/, fn ->
        TamaEx.validate_client(client, ["provision"])
      end
    end

    test "handles nested path namespaces correctly" do
      client = TamaEx.client(base_url: "https://api.example.com/v1/provision")

      assert {:ok, ^client} = TamaEx.validate_client(client, ["provision"])
    end

    test "error message includes expected and actual namespaces" do
      client = TamaEx.client(base_url: "https://api.example.com/wrong")

      error_message =
        try do
          TamaEx.validate_client(client, ["provision", "ingest"])
        rescue
          e in ArgumentError -> e.message
        end

      assert error_message =~ "Expected one of [\"provision\", \"ingest\"]"
      assert error_message =~ "got 'wrong'"
    end

    test "handles complex URLs with query parameters" do
      client = TamaEx.client(base_url: "https://api.example.com/provision?version=v1")

      assert {:ok, ^client} = TamaEx.validate_client(client, ["provision"])
    end

    test "handles URLs with ports" do
      client = TamaEx.client(base_url: "https://api.example.com:8080/provision")

      assert {:ok, ^client} = TamaEx.validate_client(client, ["provision"])
    end

    test "handles URLs with subdirectories" do
      client = TamaEx.client(base_url: "https://api.example.com/api/v1/provision")

      assert {:ok, ^client} = TamaEx.validate_client(client, ["provision"])
    end

    test "handles case-sensitive namespaces" do
      client = TamaEx.client(base_url: "https://api.example.com/Provision")

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        TamaEx.validate_client(client, ["provision"])
      end
    end
  end

  describe "integration scenarios" do
    test "typical API workflow with valid client" do
      # Create client
      client = TamaEx.client(base_url: "https://api.example.com/provision")

      # Validate client
      assert {:ok, validated_client} = TamaEx.validate_client(client, ["provision"])
      assert validated_client == client

      # Simulate successful response handling
      response = {:ok, %Req.Response{status: 200, body: %{"data" => %{"id" => "space-123"}}}}

      assert {:ok, %{parsed: %{"id" => "space-123"}}} =
               TamaEx.handle_response(response, TestSchema)
    end

    test "error handling workflow - invalid namespace" do
      # Create client with wrong namespace
      client = TamaEx.client(base_url: "https://api.example.com/wrong")

      # Should raise error during validation
      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        TamaEx.validate_client(client, ["provision"])
      end
    end

    test "API error response workflow" do
      client = TamaEx.client(base_url: "https://api.example.com/provision")

      # Validate client successfully
      assert {:ok, _} = TamaEx.validate_client(client, ["provision"])

      # Handle API error response
      error_response =
        {:ok, %Req.Response{status: 422, body: %{"errors" => %{"name" => ["required"]}}}}

      assert {:error, {:validation_error, %{"name" => ["required"]}}} =
               TamaEx.handle_response(error_response, TestSchema)
    end

    test "network error workflow" do
      client = TamaEx.client(base_url: "https://api.example.com/provision")

      # Validate client successfully
      assert {:ok, _} = TamaEx.validate_client(client, ["provision"])

      # Handle network error
      network_error = {:error, :timeout}

      assert {:error, {:request_failed, :timeout}} =
               TamaEx.handle_response(network_error, TestSchema)
    end

    test "complete workflow with multiple validations" do
      # Test multiple different clients
      provision_client = TamaEx.client(base_url: "https://api.example.com/provision")
      ingest_client = TamaEx.client(base_url: "https://api.example.com/ingest")

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
    test "handles URLs with fragment" do
      client = TamaEx.client(base_url: "https://api.example.com/provision#section")

      assert {:ok, ^client} = TamaEx.validate_client(client, ["provision"])
    end

    test "handles URLs with multiple path segments" do
      client = TamaEx.client(base_url: "https://api.example.com/v1/api/provision/endpoint")

      assert {:ok, ^client} = TamaEx.validate_client(client, ["endpoint"])
    end

    test "validates empty namespace list raises function clause error" do
      client = TamaEx.client(base_url: "https://api.example.com/provision")

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        TamaEx.validate_client(client, [])
      end
    end

    test "handles malformed URL gracefully" do
      # This test assumes the URL parsing doesn't fail completely
      client = %Req.Request{options: %{base_url: "not-a-url"}}

      # URI.parse treats "not-a-url" as having no path, so it extracts "not-a-url" as namespace
      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        TamaEx.validate_client(client, ["provision"])
      end
    end
  end
end
