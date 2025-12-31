defmodule TamaEx.NeuralTest do
  use ExUnit.Case
  import TestHelpers
  # Disable doctests due to undefined client variable in examples
  # doctest TamaEx.Neural

  alias TamaEx.Neural
  alias TamaEx.Neural.Space
  alias TamaEx.Neural.Class
  alias TamaEx.Neural.Node
  alias TamaEx.Neural.Class.Operation.Params, as: OperationParams

  # Test helper for creating a mock space
  defp mock_space(id \\ "space_123") do
    %Space{
      id: id,
      name: "Test Space",
      slug: "test-space",
      type: "neural",
      provision_state: "active"
    }
  end

  # Test helper for creating a mock class
  defp mock_class(id \\ "class_123", space_id \\ "space_123") do
    %Class{
      id: id,
      space_id: space_id,
      name: "Test Class",
      provision_state: "active"
    }
  end

  setup do
    {bypass, base_url} = setup_bypass_with_auth()

    {:ok, %{client: base_client}} =
      TamaEx.client(base_url, "test_client", "test_secret")

    neural_client = TamaEx.put_namespace(base_client, "neural")

    {:ok, bypass: bypass, client: neural_client}
  end

  describe "get_space/2" do
    test "validates required client namespace" do
      # Test with wrong namespace
      client = mock_client("ingest")
      slug = "test-space"

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        Neural.get_space(client, slug)
      end
    end

    test "validates slug parameter type" do
      client = mock_client("provision")

      # Test with non-string slug
      assert_raise FunctionClauseError, fn ->
        Neural.get_space(client, 123)
      end
    end

    test "handles client validation errors" do
      # Test client without base_url
      invalid_client = %Req.Request{options: %{}}
      slug = "test-space"

      assert_raise ArgumentError, ~r/Failed to extract namespace/, fn ->
        Neural.get_space(invalid_client, slug)
      end
    end

    test "handles malformed client gracefully" do
      malformed_client = %Req.Request{options: %{base_url: "not-a-url"}}
      slug = "test-space"

      assert_raise ArgumentError, fn ->
        Neural.get_space(malformed_client, slug)
      end
    end
  end

  describe "get_class/3" do
    test "validates required client namespace" do
      # Test with wrong namespace
      client = mock_client("ingest")
      space = mock_space()
      name = "test-class"

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        Neural.get_class(client, space, name)
      end
    end

    test "validates name parameter type" do
      client = mock_client("provision")
      space = mock_space()

      # Test with non-string name
      assert_raise FunctionClauseError, fn ->
        Neural.get_class(client, space, 123)
      end
    end

    test "handles client validation errors" do
      invalid_client = %Req.Request{options: %{}}
      space = mock_space()
      name = "test-class"

      assert_raise ArgumentError, ~r/Failed to extract namespace/, fn ->
        Neural.get_class(invalid_client, space, name)
      end
    end
  end

  describe "create_class_operation/3" do
    test "validates required client namespace" do
      # Test with wrong namespace
      client = mock_client("ingest")
      class = mock_class()
      attrs = %{"chain_ids" => ["chain1", "chain2"]}

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        Neural.create_class_operation(client, class, attrs)
      end
    end

    test "validates operation parameters" do
      _client = mock_client("provision")
      _class = mock_class()

      # Missing required fields
      invalid_attrs = %{}

      # This should fail at parameter validation step, before any HTTP call
      assert {:error, %Ecto.Changeset{}} = OperationParams.validate(invalid_attrs)

      # Missing chain_ids
      attrs_missing_chain_ids = %{"node_type" => "compute"}
      assert {:error, changeset} = OperationParams.validate(attrs_missing_chain_ids)
      assert changeset.errors[:chain_ids]

      # Empty chain_ids
      attrs_empty_chain_ids = %{"chain_ids" => []}
      assert {:error, changeset} = OperationParams.validate(attrs_empty_chain_ids)
      assert changeset.errors[:chain_ids]
    end

    test "handles client validation errors" do
      invalid_client = %Req.Request{options: %{}}
      class = mock_class()
      attrs = %{"chain_ids" => ["chain1"]}

      assert_raise ArgumentError, ~r/Failed to extract namespace/, fn ->
        Neural.create_class_operation(invalid_client, class, attrs)
      end
    end

    test "parameter validation fails early" do
      _client = mock_client("provision")
      _class = mock_class()
      invalid_attrs = %{"invalid" => "params"}

      # This should fail at parameter validation step, before any HTTP call
      assert {:error, %Ecto.Changeset{}} = OperationParams.validate(invalid_attrs)
    end
  end

  describe "list_nodes/3" do
    test "validates required client namespace", %{bypass: bypass} do
      # Test with wrong namespace
      client = mock_client("ingest", "http://localhost:#{bypass.port}")
      class = mock_class()

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        Neural.list_nodes(client, class)
      end
    end

    test "handles successful list response", %{bypass: bypass, client: client} do
      class = mock_class("class_123")

      Bypass.expect(bypass, "GET", "/neural/classes/#{class.id}/nodes", fn conn ->
        response_data = %{
          "data" => [
            %{
              "id" => "node_001",
              "type" => "compute",
              "on" => "server-01",
              "provision_state" => "active",
              "chain" => %{
                "id" => "chain_001",
                "name" => "Production Chain"
              }
            },
            %{
              "id" => "node_002",
              "type" => "storage",
              "on" => "server-02",
              "provision_state" => "pending",
              "chain" => %{
                "id" => "chain_002",
                "name" => "Storage Chain"
              }
            }
          ]
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response_data))
      end)

      assert {:ok, nodes} = Neural.list_nodes(client, class)
      assert is_list(nodes)
      assert length(nodes) == 2

      [node1, node2] = nodes
      assert %Node{} = node1
      assert node1.id == "node_001"
      assert node1.type == "compute"
      assert node1.on == "server-01"
      assert node1.provision_state == "active"
      assert node1.chain.id == "chain_001"
      assert node1.chain.name == "Production Chain"

      assert %Node{} = node2
      assert node2.id == "node_002"
      assert node2.type == "storage"
      assert node2.on == "server-02"
      assert node2.provision_state == "pending"
      assert node2.chain.id == "chain_002"
      assert node2.chain.name == "Storage Chain"
    end

    test "handles empty list response", %{bypass: bypass, client: client} do
      class = mock_class("class_empty")

      Bypass.expect(bypass, "GET", "/neural/classes/#{class.id}/nodes", fn conn ->
        response_data = %{"data" => []}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response_data))
      end)

      assert {:ok, nodes} = Neural.list_nodes(client, class)
      assert is_list(nodes)
      assert length(nodes) == 0
    end

    test "passes query parameters", %{bypass: bypass, client: client} do
      class = mock_class("class_456")
      query_params = [limit: 10, offset: 0, type: "compute"]

      Bypass.expect(bypass, "GET", "/neural/classes/#{class.id}/nodes", fn conn ->
        # Verify query parameters are passed correctly
        assert conn.query_string =~ "limit=10"
        assert conn.query_string =~ "offset=0"
        assert conn.query_string =~ "type=compute"

        response_data = %{
          "data" => [
            %{
              "id" => "node_filtered",
              "type" => "compute",
              "on" => "server-filtered",
              "provision_state" => "active",
              "chain" => %{
                "id" => "chain_filtered",
                "name" => "Filtered Chain"
              }
            }
          ]
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response_data))
      end)

      assert {:ok, nodes} = Neural.list_nodes(client, class, query: query_params)

      assert length(nodes) == 1

      [node] = nodes
      assert node.id == "node_filtered"
      assert node.type == "compute"
    end

    test "handles 404 not found", %{bypass: bypass, client: client} do
      class = mock_class("nonexistent_class")

      Bypass.expect(bypass, "GET", "/neural/classes/#{class.id}/nodes", fn conn ->
        conn
        |> Plug.Conn.resp(404, "")
      end)

      assert {:error, :not_found} = Neural.list_nodes(client, class, retry: false)
    end

    test "handles 422 validation errors", %{bypass: bypass, client: client} do
      class = mock_class("invalid_class")

      Bypass.expect(bypass, "GET", "/neural/classes/#{class.id}/nodes", fn conn ->
        error_response = %{
          "errors" => [
            %{"field" => "class_id", "message" => "is invalid"}
          ]
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(422, Jason.encode!(error_response))
      end)

      assert {:error, {:validation_error, errors}} =
               Neural.list_nodes(client, class, retry: false)

      assert is_list(errors)
    end

    test "handles server errors", %{bypass: bypass, client: client} do
      class = mock_class("error_class")

      Bypass.expect(bypass, "GET", "/neural/classes/#{class.id}/nodes", fn conn ->
        conn
        |> Plug.Conn.resp(500, "Internal Server Error")
      end)

      assert {:error, _} = Neural.list_nodes(client, class, retry: false)
    end

    test "handles network errors", %{bypass: bypass, client: client} do
      class = mock_class("network_error_class")

      Bypass.down(bypass)

      assert {:error, {:request_failed, %Req.TransportError{reason: :econnrefused}}} =
               Neural.list_nodes(client, class, retry: false)

      Bypass.up(bypass)
    end

    test "handles malformed response data gracefully", %{bypass: bypass, client: client} do
      class = mock_class("malformed_class")

      Bypass.expect(bypass, "GET", "/neural/classes/#{class.id}/nodes", fn conn ->
        # Missing required fields in node data
        response_data = %{
          "data" => [
            %{
              "id" => "node_incomplete"
              # Missing type, on, chain
            },
            %{
              "id" => "node_002",
              "type" => "compute",
              "on" => "server-02",
              "provision_state" => "active",
              "chain" => %{
                "id" => "chain_002",
                "name" => "Valid Chain"
              }
            }
          ]
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response_data))
      end)

      # Should handle malformed data gracefully
      assert {:ok, nodes} = Neural.list_nodes(client, class)
      assert is_list(nodes)
      # The parser should create structs for all items, even if incomplete
      assert length(nodes) == 2
    end

    test "handles client validation errors" do
      invalid_client = %Req.Request{options: %{}}
      class = mock_class()

      assert_raise ArgumentError, ~r/Failed to extract namespace/, fn ->
        Neural.list_nodes(invalid_client, class)
      end
    end
  end

  describe "error handling scenarios" do
    test "handles client validation errors for all functions" do
      invalid_client = %Req.Request{options: %{}}
      space = mock_space()
      class = mock_class()

      # get_space
      assert_raise ArgumentError, ~r/Failed to extract namespace/, fn ->
        Neural.get_space(invalid_client, "test")
      end

      # get_class
      assert_raise ArgumentError, ~r/Failed to extract namespace/, fn ->
        Neural.get_class(invalid_client, space, "test")
      end

      # create_class_operation
      assert_raise ArgumentError, ~r/Failed to extract namespace/, fn ->
        Neural.create_class_operation(invalid_client, class, %{"chain_ids" => ["chain1"]})
      end

      # list_nodes
      assert_raise ArgumentError, ~r/Failed to extract namespace/, fn ->
        Neural.list_nodes(invalid_client, class)
      end
    end

    test "validates namespace requirement for all functions" do
      client_wrong = mock_client("ingest")
      space = mock_space()
      class = mock_class()

      # All functions should require provision namespace
      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        Neural.get_space(client_wrong, "test")
      end

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        Neural.get_class(client_wrong, space, "test")
      end

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        Neural.create_class_operation(client_wrong, class, %{"chain_ids" => ["chain1"]})
      end

      # list_nodes requires neural namespace
      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        Neural.list_nodes(client_wrong, class)
      end
    end
  end

  describe "Node struct behavior" do
    test "Node.parse handles valid individual node data" do
      node_data = %{
        "id" => "node_123",
        "type" => "compute",
        "on" => "server-01",
        "provision_state" => "active",
        "chain" => %{
          "id" => "chain_123",
          "name" => "Test Chain"
        }
      }

      node = Node.parse(node_data)

      assert %Node{} = node
      assert node.id == "node_123"
      assert node.type == "compute"
      assert node.on == "server-01"
      assert node.provision_state == "active"
      assert node.chain.id == "chain_123"
      assert node.chain.name == "Test Chain"
    end

    test "Node.parse handles list of nodes" do
      nodes_data = [
        %{
          "id" => "node_001",
          "type" => "compute",
          "on" => "server-01",
          "provision_state" => "active",
          "chain" => %{
            "id" => "chain_001",
            "name" => "Chain 1"
          }
        },
        %{
          "id" => "node_002",
          "type" => "storage",
          "on" => "server-02",
          "provision_state" => "pending",
          "chain" => %{
            "id" => "chain_002",
            "name" => "Chain 2"
          }
        }
      ]

      nodes = Node.parse(nodes_data)

      assert is_list(nodes)
      assert length(nodes) == 2
      assert Enum.all?(nodes, &match?(%Node{}, &1))
      assert Enum.at(nodes, 0).id == "node_001"
      assert Enum.at(nodes, 1).id == "node_002"
    end

    test "Node.parse handles invalid data gracefully" do
      invalid_data = %{
        "id" => "node_incomplete"
        # Missing required type field
      }

      node = Node.parse(invalid_data)

      # Should return empty struct for invalid data
      assert %Node{} = node
      assert node.id == nil
    end

    test "Node.parse handles JSON string input" do
      json_string = """
      {
        "id": "node_json",
        "type": "compute",
        "on": "server-json",
        "provision_state": "active",
        "chain": {
          "id": "chain_json",
          "name": "JSON Chain"
        }
      }
      """

      node = Node.parse(json_string)

      assert %Node{} = node
      assert node.id == "node_json"
      assert node.type == "compute"
    end

    test "Node.parse handles invalid JSON gracefully" do
      invalid_json = "not valid json"

      node = Node.parse(invalid_json)

      assert %Node{} = node
      assert node.id == nil
    end

    test "Node.parse handles non-map, non-string input" do
      node = Node.parse(nil)

      assert %Node{} = node
    end

    test "Node.parse! creates valid node struct" do
      node_data = %{
        "id" => "node_valid",
        "type" => "compute",
        "on" => "server-valid",
        "provision_state" => "active",
        "chain" => %{
          "id" => "chain_valid",
          "name" => "Valid Chain"
        }
      }

      node = Node.parse!(node_data)

      assert %Node{} = node
      assert node.id == "node_valid"
      assert node.type == "compute"
    end

    test "Node.parse! raises on invalid data" do
      invalid_data = %{
        "invalid" => "data"
      }

      assert_raise Ecto.InvalidChangesetError, fn ->
        Node.parse!(invalid_data)
      end
    end

    test "Node changeset validation enforces required fields" do
      changeset = Node.changeset(%Node{}, %{})

      refute changeset.valid?
      assert changeset.errors[:id]
      assert changeset.errors[:type]
    end

    test "Node changeset accepts all fields" do
      attrs = %{
        "id" => "node_complete",
        "type" => "compute",
        "on" => "server-complete",
        "provision_state" => "active",
        "chain" => %{
          "id" => "chain_complete",
          "name" => "Complete Chain"
        }
      }

      changeset = Node.changeset(%Node{}, attrs)

      assert changeset.valid?
      node = Ecto.Changeset.apply_changes(changeset)
      assert node.id == "node_complete"
      assert node.type == "compute"
      assert node.on == "server-complete"
      assert node.provision_state == "active"
      assert node.chain.id == "chain_complete"
      assert node.chain.name == "Complete Chain"
    end
  end
end
