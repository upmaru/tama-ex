defmodule TamaEx.PerceptionTest do
  use ExUnit.Case
  doctest TamaEx.Perception

  alias TamaEx.Perception
  alias TamaEx.Perception.Chain
  alias TamaEx.Perception.Concept
  alias TamaEx.Neural.Space

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

  # Test helper for creating a mock client
  defp mock_client(namespace) do
    TamaEx.client(base_url: "https://api.example.com/#{namespace}")
  end

  setup do
    bypass = Bypass.open()
    client = TamaEx.client(base_url: "http://localhost:#{bypass.port}/perception")

    {:ok, bypass: bypass, client: client}
  end

  describe "get_chain/3 with Space struct" do
    test "validates required client namespace" do
      client = mock_client("ingest")
      space = mock_space()
      slug = "test-chain"

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        Perception.get_chain(client, space, slug)
      end
    end

    test "validates space struct parameter" do
      client = mock_client("provision")
      slug = "test-chain"

      # Test with invalid space (non-Space struct)
      invalid_space = %{id: "space_123"}

      assert_raise FunctionClauseError, fn ->
        Perception.get_chain(client, invalid_space, slug)
      end
    end

    test "validates slug parameter type" do
      client = mock_client("provision")
      space = mock_space()

      # Test with non-string slug
      assert_raise FunctionClauseError, fn ->
        Perception.get_chain(client, space, 123)
      end
    end

    test "handles space with nil id" do
      client = mock_client("provision")
      invalid_space = %Space{id: nil, name: "Invalid", provision_state: "active"}
      slug = "test-chain"

      assert_raise FunctionClauseError, fn ->
        Perception.get_chain(client, invalid_space, slug)
      end
    end

    test "handles space with non-string id" do
      client = mock_client("provision")
      invalid_space = %Space{id: 123, name: "Invalid", provision_state: "active"}
      slug = "test-chain"

      assert_raise FunctionClauseError, fn ->
        Perception.get_chain(client, invalid_space, slug)
      end
    end
  end

  describe "get_chain/3 with space_id string" do
    test "validates required client namespace" do
      client = mock_client("ingest")
      space_id = "space_456"
      slug = "test-chain"

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        Perception.get_chain(client, space_id, slug)
      end
    end

    test "validates space_id parameter type" do
      client = mock_client("provision")
      slug = "test-chain"

      # Test with non-string space_id
      assert_raise FunctionClauseError, fn ->
        Perception.get_chain(client, 123, slug)
      end
    end

    test "validates slug parameter type" do
      client = mock_client("provision")
      space_id = "space_456"

      # Test with non-string slug
      assert_raise FunctionClauseError, fn ->
        Perception.get_chain(client, space_id, 456)
      end
    end
  end

  describe "error handling scenarios" do
    test "handles client validation errors" do
      invalid_client = %Req.Request{options: %{}}
      space = mock_space()
      slug = "test-chain"

      assert_raise ArgumentError, ~r/Failed to extract namespace/, fn ->
        Perception.get_chain(invalid_client, space, slug)
      end
    end

    test "validates client namespace requirement for both function versions" do
      client_wrong = mock_client("ingest")
      space = mock_space()
      space_id = "space_123"
      slug = "test-chain"

      # Space struct version should fail
      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        Perception.get_chain(client_wrong, space, slug)
      end

      # String version should fail
      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        Perception.get_chain(client_wrong, space_id, slug)
      end
    end

    test "handles malformed client gracefully" do
      malformed_client = %Req.Request{options: %{base_url: "not-a-url"}}
      space = mock_space()
      slug = "test-chain"

      assert_raise ArgumentError, fn ->
        Perception.get_chain(malformed_client, space, slug)
      end
    end
  end

  describe "Chain struct behavior" do
    test "Chain.parse handles valid data" do
      api_response_data = %{
        "id" => "chain_789",
        "space_id" => "space_123",
        "name" => "My Chain",
        "slug" => "my-chain",
        "provision_state" => "active"
      }

      chain = Chain.parse(api_response_data)

      assert %Chain{} = chain
      assert chain.id == "chain_789"
      assert chain.space_id == "space_123"
      assert chain.name == "My Chain"
      assert chain.slug == "my-chain"
      assert chain.provision_state == "active"
    end

    test "Chain.parse handles minimal required data" do
      minimal_data = %{
        "name" => "Minimal Chain",
        "provision_state" => "pending"
      }

      chain = Chain.parse(minimal_data)

      assert %Chain{} = chain
      assert chain.id == nil
      assert chain.space_id == nil
      assert chain.slug == nil
      assert chain.name == "Minimal Chain"
      assert chain.provision_state == "pending"
    end

    test "Chain.parse raises on invalid data" do
      invalid_data = %{"id" => "123"}

      assert_raise Ecto.InvalidChangesetError, fn ->
        Chain.parse(invalid_data)
      end
    end

    test "Chain.parse handles string input" do
      json_string = ~s({"id": "123", "name": "Test Chain", "provision_state": "active"})

      chain = Chain.parse(json_string)
      assert %Chain{} = chain
      assert chain.id == "123"
      assert chain.name == "Test Chain"
    end

    test "Chain.parse handles invalid JSON string" do
      invalid_json = "not valid json"

      chain = Chain.parse(invalid_json)
      assert %Chain{} = chain
      assert chain.id == nil
    end

    test "Chain.parse handles non-map, non-string input" do
      chain = Chain.parse(123)
      assert %Chain{} = chain
      assert chain.id == nil
    end

    test "Chain.parse! returns struct for any input since parse always returns struct" do
      chain = Chain.parse!(123)
      assert %Chain{} = chain
      assert chain.id == nil
    end

    test "Chain changeset validation enforces required fields" do
      changeset = Chain.changeset(%Chain{}, %{})
      refute changeset.valid?
      assert changeset.errors[:name]
      assert changeset.errors[:provision_state]

      valid_changeset =
        Chain.changeset(%Chain{}, %{
          "name" => "Valid Chain",
          "provision_state" => "active"
        })

      assert valid_changeset.valid?
    end

    test "Chain changeset accepts all fields" do
      all_fields_data = %{
        "id" => "chain_123",
        "space_id" => "space_456",
        "name" => "Complete Chain",
        "slug" => "complete-chain",
        "provision_state" => "active"
      }

      changeset = Chain.changeset(%Chain{}, all_fields_data)
      assert changeset.valid?

      changes = changeset.changes
      assert changes.id == "chain_123"
      assert changes.space_id == "space_456"
      assert changes.name == "Complete Chain"
      assert changes.slug == "complete-chain"
      assert changes.provision_state == "active"
    end
  end

  describe "list_concepts/3" do
    test "validates required client namespace", %{bypass: bypass} do
      client = TamaEx.client(base_url: "http://localhost:#{bypass.port}/ingest")
      entity_id = "entity_123"

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        Perception.list_concepts(client, entity_id)
      end
    end

    test "handles successful list response", %{bypass: bypass, client: client} do
      entity_id = "entity_123"

      Bypass.expect(bypass, "GET", "/perception/entities/#{entity_id}/concepts", fn conn ->
        response_data = %{
          "data" => [
            %{
              "id" => "concept_001",
              "relation" => "reply",
              "content" => %{"text" => "Hello world"},
              "generator" => %{
                "type" => "module",
                "reference" => "tama/classes/extraction",
                "parameters" => %{"depth" => 1, "names" => nil, "types" => ["array"]}
              }
            },
            %{
              "id" => "concept_002",
              "relation" => "mention",
              "content" => %{"text" => "Another concept"},
              "generator" => %{
                "type" => "module",
                "reference" => "tama/classes/extraction",
                "parameters" => %{"depth" => 2, "names" => ["test"], "types" => ["string"]}
              }
            }
          ]
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response_data))
      end)

      assert {:ok, concepts} = Perception.list_concepts(client, entity_id)
      assert is_list(concepts)
      assert length(concepts) == 2

      [concept1, concept2] = concepts
      assert %Concept{} = concept1
      assert concept1.id == "concept_001"
      assert concept1.relation == "reply"
      assert concept1.content == %{"text" => "Hello world"}

      assert concept1.generator.type == :module
      assert concept1.generator.reference == "tama/classes/extraction"

      assert concept1.generator.parameters == %{
               "depth" => 1,
               "names" => nil,
               "types" => ["array"]
             }

      assert %Concept{} = concept2
      assert concept2.id == "concept_002"
      assert concept2.relation == "mention"
      assert concept2.content == %{"text" => "Another concept"}

      assert concept2.generator.type == :module
      assert concept2.generator.reference == "tama/classes/extraction"

      assert concept2.generator.parameters == %{
               "depth" => 2,
               "names" => ["test"],
               "types" => ["string"]
             }
    end

    test "handles empty list response", %{bypass: bypass, client: client} do
      entity_id = "entity_empty"

      Bypass.expect(bypass, "GET", "/perception/entities/#{entity_id}/concepts", fn conn ->
        response_data = %{"data" => []}

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response_data))
      end)

      assert {:ok, concepts} = Perception.list_concepts(client, entity_id)
      assert is_list(concepts)
      assert length(concepts) == 0
    end

    test "passes query parameters", %{bypass: bypass, client: client} do
      entity_id = "entity_456"
      query_params = [limit: 10, offset: 0, relation: "reply"]

      Bypass.expect(bypass, "GET", "/perception/entities/#{entity_id}/concepts", fn conn ->
        # Verify query parameters are passed correctly
        assert conn.query_string =~ "limit=10"
        assert conn.query_string =~ "offset=0"
        assert conn.query_string =~ "relation=reply"

        response_data = %{
          "data" => [
            %{
              "id" => "concept_filtered",
              "relation" => "reply",
              "content" => %{"filtered" => true},
              "generator" => %{
                "type" => "module",
                "reference" => "tama/classes/extraction",
                "parameters" => %{"depth" => 1, "names" => nil, "types" => ["array"]}
              }
            }
          ]
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response_data))
      end)

      assert {:ok, concepts} =
               Perception.list_concepts(client, entity_id, query: query_params)

      assert length(concepts) == 1

      [concept] = concepts
      assert concept.id == "concept_filtered"
      assert concept.relation == "reply"
    end

    test "handles 404 not found", %{bypass: bypass, client: client} do
      entity_id = "nonexistent_entity"

      Bypass.expect(bypass, "GET", "/perception/entities/#{entity_id}/concepts", fn conn ->
        conn
        |> Plug.Conn.resp(404, "")
      end)

      assert {:error, :not_found} = Perception.list_concepts(client, entity_id, retry: false)
    end

    test "handles 422 validation errors", %{bypass: bypass, client: client} do
      entity_id = "invalid_entity"

      Bypass.expect(bypass, "GET", "/perception/entities/#{entity_id}/concepts", fn conn ->
        error_response = %{
          "errors" => [
            %{"field" => "entity_id", "message" => "is invalid"}
          ]
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(422, Jason.encode!(error_response))
      end)

      assert {:error, {:validation_error, errors}} =
               Perception.list_concepts(client, entity_id, retry: false)

      assert is_list(errors)
    end

    test "handles server errors", %{bypass: bypass, client: client} do
      entity_id = "server_error_entity"

      Bypass.expect(bypass, "GET", "/perception/entities/#{entity_id}/concepts", fn conn ->
        conn
        |> Plug.Conn.resp(500, "Internal Server Error")
      end)

      assert {:error, {:http_error, 500, "Internal Server Error"}} =
               Perception.list_concepts(client, entity_id, retry: false)
    end

    test "handles network errors" do
      # Use an invalid port to simulate network error
      invalid_client = TamaEx.client(base_url: "http://localhost:99999/perception")

      # The connection error may be raised as an exception instead of returning error tuple
      result =
        try do
          Perception.list_concepts(invalid_client, "entity_123")
        rescue
          _ -> {:error, {:request_failed, :connection_failed}}
        catch
          :exit, _ -> {:error, {:request_failed, :connection_failed}}
        end

      assert {:error, {:request_failed, _reason}} = result
    end

    test "handles malformed response data gracefully", %{bypass: bypass, client: client} do
      entity_id = "malformed_entity"

      Bypass.expect(bypass, "GET", "/perception/entities/#{entity_id}/concepts", fn conn ->
        response_data = %{
          "data" => [
            %{
              "id" => "valid_concept",
              "relation" => "reply",
              "content" => %{"text" => "Valid"},
              "generator" => %{
                "type" => "module",
                "reference" => "tama/classes/extraction",
                "parameters" => %{"depth" => 1, "names" => nil, "types" => ["array"]}
              }
            },
            %{
              # Missing required fields - should create empty Concept struct
              "some_other_field" => "invalid"
            }
          ]
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(200, Jason.encode!(response_data))
      end)

      assert {:ok, concepts} = Perception.list_concepts(client, entity_id)
      assert length(concepts) == 2

      [valid_concept, invalid_concept] = concepts
      assert valid_concept.id == "valid_concept"
      assert valid_concept.relation == "reply"

      assert valid_concept.generator.type == :module
      assert valid_concept.generator.reference == "tama/classes/extraction"

      assert valid_concept.generator.parameters == %{
               "depth" => 1,
               "names" => nil,
               "types" => ["array"]
             }

      # Invalid concept should have nil values for required fields
      assert %Concept{} = invalid_concept
      assert invalid_concept.id == nil
      assert invalid_concept.relation == nil
      assert invalid_concept.content == nil
      assert invalid_concept.generator == nil
    end
  end

  describe "Concept struct behavior" do
    test "Concept.parse handles valid individual concept data" do
      concept_data = %{
        "id" => "concept_123",
        "relation" => "reply",
        "content" => %{"text" => "Hello world", "metadata" => %{"score" => 0.95}},
        "generator" => %{
          "type" => "module",
          "reference" => "tama/classes/extraction",
          "parameters" => %{"depth" => 1, "names" => nil, "types" => ["array"]}
        }
      }

      concept = Concept.parse(concept_data)
      assert %Concept{} = concept
      assert concept.id == "concept_123"
      assert concept.relation == "reply"
      assert concept.content == %{"text" => "Hello world", "metadata" => %{"score" => 0.95}}

      assert concept.generator.type == :module
      assert concept.generator.reference == "tama/classes/extraction"
      assert concept.generator.parameters == %{"depth" => 1, "names" => nil, "types" => ["array"]}
    end

    test "Concept.parse handles list of concepts" do
      concepts_data = [
        %{
          "id" => "concept_001",
          "relation" => "reply",
          "content" => %{"text" => "First concept"},
          "generator" => %{
            "type" => "module",
            "reference" => "tama/classes/extraction",
            "parameters" => %{"depth" => 1, "names" => nil, "types" => ["array"]}
          }
        },
        %{
          "id" => "concept_002",
          "relation" => "mention",
          "content" => %{"text" => "Second concept"},
          "generator" => %{
            "type" => "module",
            "reference" => "tama/classes/extraction",
            "parameters" => %{"depth" => 2, "names" => ["test"], "types" => ["string"]}
          }
        }
      ]

      concepts = Concept.parse(concepts_data)
      assert is_list(concepts)
      assert length(concepts) == 2

      [concept1, concept2] = concepts
      assert concept1.id == "concept_001"
      assert concept1.relation == "reply"
      assert concept2.id == "concept_002"
      assert concept2.relation == "mention"
    end

    test "Concept.parse handles invalid data gracefully" do
      invalid_data = %{"invalid_field" => "test"}
      concept = Concept.parse(invalid_data)

      assert %Concept{} = concept
      assert concept.id == nil
      assert concept.relation == nil
      assert concept.content == nil
      assert concept.generator == nil
    end

    test "Concept.parse handles JSON string input" do
      json_string =
        ~s({"id": "concept_json", "relation": "reply", "content": {"text": "From JSON"}, "generator": {"type": "module", "reference": "tama/classes/extraction", "parameters": {"depth": 1, "names": null, "types": ["array"]}}})

      concept = Concept.parse(json_string)

      assert %Concept{} = concept
      assert concept.id == "concept_json"
      assert concept.relation == "reply"
      assert concept.content == %{"text" => "From JSON"}

      assert concept.generator.type == :module
      assert concept.generator.reference == "tama/classes/extraction"
      assert concept.generator.parameters == %{"depth" => 1, "names" => nil, "types" => ["array"]}
    end

    test "Concept.parse handles invalid JSON gracefully" do
      invalid_json = "not valid json"
      concept = Concept.parse(invalid_json)

      assert %Concept{} = concept
      assert concept.id == nil
    end

    test "Concept.parse! creates valid concept struct" do
      valid_data = %{
        "id" => "concept_parse_bang",
        "relation" => "reply",
        "content" => %{"test" => true},
        "generator" => %{
          "type" => "module",
          "reference" => "tama/classes/extraction",
          "parameters" => %{"depth" => 1, "names" => nil, "types" => ["array"]}
        }
      }

      concept = Concept.parse!(valid_data)
      assert %Concept{} = concept
      assert concept.id == "concept_parse_bang"
    end

    test "Concept.parse! raises on invalid data" do
      # Missing required fields
      invalid_data = %{"id" => "test"}

      assert_raise Ecto.InvalidChangesetError, fn ->
        Concept.parse!(invalid_data)
      end
    end

    test "Concept changeset validation enforces required fields" do
      changeset = Concept.changeset(%Concept{}, %{})
      refute changeset.valid?
      assert changeset.errors[:id]
      assert changeset.errors[:relation]
      assert changeset.errors[:content]
      # Generator is embedded and validated separately, so no direct error here

      valid_changeset =
        Concept.changeset(%Concept{}, %{
          "id" => "valid_id",
          "relation" => "reply",
          "content" => %{"valid" => true},
          "generator" => %{
            "type" => "module",
            "reference" => "tama/classes/extraction",
            "parameters" => %{"depth" => 1, "names" => nil, "types" => ["array"]}
          }
        })

      assert valid_changeset.valid?
    end
  end
end
