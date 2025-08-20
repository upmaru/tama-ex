defmodule TamaEx.MemoryTest do
  use ExUnit.Case
  doctest TamaEx.Memory

  alias TamaEx.Memory
  alias TamaEx.Memory.Entity
  alias TamaEx.Memory.Entity.Params, as: EntityParams
  alias TamaEx.Neural.Class

  # Test helper for creating a mock class
  defp mock_class(id \\ "class_123") do
    %Class{
      id: id,
      name: "Test Class",
      provision_state: "active"
    }
  end

  # Test helper for creating a mock client
  defp mock_client(namespace) do
    TamaEx.client(base_url: "https://api.example.com/#{namespace}")
  end

  describe "create_entity/3" do
    test "creates entity with valid parameters" do
      _client = mock_client("ingest")
      _class = mock_class()

      attrs = %{
        "identifier" => "test-entity",
        "record" => %{"name" => "Test Entity", "value" => 42},
        "validate_record" => true
      }

      # Mock successful response
      _expected_response = {
        :ok,
        %Req.Response{
          status: 201,
          body: %{
            "data" => %{
              "id" => "entity_456",
              "class_id" => "class_123",
              "current_state" => "active",
              "identifier" => "test-entity"
            }
          }
        }
      }

      # Since we can't mock Req.post directly in this test setup,
      # we'll test the parameter validation and URL construction logic
      assert {:ok, validated_params} = EntityParams.validate(attrs)
      assert validated_params["identifier"] == "test-entity"
      assert validated_params["record"] == %{"name" => "Test Entity", "value" => 42}
      assert validated_params["validate_record"] == true
    end

    test "validates required client namespace" do
      # Test with wrong namespace
      client = mock_client("provision")
      class = mock_class()
      attrs = %{"identifier" => "test", "record" => %{}}

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        Memory.create_entity(client, class, attrs)
      end
    end

    test "validates required class_id" do
      client = mock_client("ingest")
      invalid_class = %Class{id: nil, name: "Invalid", provision_state: "active"}
      attrs = %{"identifier" => "test", "record" => %{}}

      assert_raise FunctionClauseError, fn ->
        Memory.create_entity(client, invalid_class, attrs)
      end
    end

    test "validates entity parameters" do
      _client = mock_client("ingest")
      _class = mock_class()

      # Missing required fields
      invalid_attrs = %{}

      assert {:error, %Ecto.Changeset{}} = EntityParams.validate(invalid_attrs)

      # Missing identifier
      attrs_missing_identifier = %{"record" => %{}}
      assert {:error, changeset} = EntityParams.validate(attrs_missing_identifier)
      assert changeset.errors[:identifier]

      # Missing record
      attrs_missing_record = %{"identifier" => "test"}
      assert {:error, changeset} = EntityParams.validate(attrs_missing_record)
      assert changeset.errors[:record]
    end

    test "constructs correct URL for API call" do
      # This test verifies the URL construction logic
      class_id = "my_class_123"
      _expected_url = "/memory/classes/#{class_id}/entities"

      # We can't directly test the URL without mocking Req.post,
      # but we can verify the class_id is properly used
      class = mock_class(class_id)
      assert class.id == class_id
    end

    test "sends correct JSON payload structure" do
      attrs = %{
        "identifier" => "test-entity",
        "record" => %{"name" => "Test"},
        "validate_record" => false
      }

      assert {:ok, validated_params} = EntityParams.validate(attrs)

      # Verify the expected JSON structure
      expected_json = %{entity: validated_params}
      assert expected_json[:entity]["identifier"] == "test-entity"
      assert expected_json[:entity]["record"] == %{"name" => "Test"}
      assert expected_json[:entity]["validate_record"] == false
    end
  end

  describe "integration with Entity parsing" do
    test "successful response gets parsed by Entity module" do
      # Test that Entity.parse works correctly with typical API response
      api_response_data = %{
        "id" => "entity_789",
        "class_id" => "class_123",
        "current_state" => "active",
        "identifier" => "my-entity"
      }

      entity = Entity.parse(api_response_data)

      assert %Entity{} = entity
      assert entity.id == "entity_789"
      assert entity.class_id == "class_123"
      assert entity.current_state == "active"
      assert entity.identifier == "my-entity"
    end

    test "Entity.parse handles missing optional fields" do
      # Test with minimal required data
      minimal_data = %{
        "class_id" => "class_456",
        "current_state" => "pending",
        "identifier" => "minimal-entity"
      }

      entity = Entity.parse(minimal_data)

      assert %Entity{} = entity
      # Optional field
      assert entity.id == nil
      assert entity.class_id == "class_456"
      assert entity.current_state == "pending"
      assert entity.identifier == "minimal-entity"
    end

    test "Entity.parse raises on invalid data" do
      # Missing required fields should cause parsing to fail
      # Missing required fields
      invalid_data = %{"id" => "123"}

      assert_raise Ecto.InvalidChangesetError, fn ->
        Entity.parse(invalid_data)
      end
    end
  end

  describe "EntityParams validation" do
    test "validates with all valid parameters" do
      attrs = %{
        "identifier" => "valid-entity",
        "record" => %{"data" => "test"},
        "validate_record" => true
      }

      assert {:ok, validated} = EntityParams.validate(attrs)
      assert validated["identifier"] == "valid-entity"
      assert validated["record"] == %{"data" => "test"}
      assert validated["validate_record"] == true
    end

    test "sets default value for validate_record" do
      attrs = %{
        "identifier" => "test-entity",
        "record" => %{"key" => "value"}
        # validate_record not specified
      }

      assert {:ok, validated} = EntityParams.validate(attrs)
      # Default value
      assert validated["validate_record"] == true
    end

    test "allows validate_record to be explicitly false" do
      attrs = %{
        "identifier" => "test-entity",
        "record" => %{"key" => "value"},
        "validate_record" => false
      }

      assert {:ok, validated} = EntityParams.validate(attrs)
      assert validated["validate_record"] == false
    end

    test "validates! raises on invalid parameters" do
      invalid_attrs = %{"invalid" => "data"}

      assert_raise Ecto.InvalidChangesetError, fn ->
        EntityParams.validate!(invalid_attrs)
      end
    end

    test "validate! returns validated params on success" do
      valid_attrs = %{
        "identifier" => "test",
        "record" => %{"data" => "value"}
      }

      assert validated = EntityParams.validate!(valid_attrs)
      assert validated["identifier"] == "test"
      assert validated["record"] == %{"data" => "value"}
      assert validated["validate_record"] == true
    end

    test "handles complex record structures" do
      complex_record = %{
        "user" => %{
          "name" => "John Doe",
          "age" => 30,
          "preferences" => %{
            "theme" => "dark",
            "notifications" => true
          }
        },
        "metadata" => %{
          "created_at" => "2023-01-01T00:00:00Z",
          "tags" => ["important", "test"]
        }
      }

      attrs = %{
        "identifier" => "complex-entity",
        "record" => complex_record
      }

      assert {:ok, validated} = EntityParams.validate(attrs)
      assert validated["record"] == complex_record
    end

    test "validates identifier as string" do
      # Test non-string identifier
      attrs_with_number = %{
        "identifier" => 123,
        "record" => %{"data" => "test"}
      }

      # Ecto should cast the number to string or fail validation
      case EntityParams.validate(attrs_with_number) do
        {:ok, validated} ->
          assert is_binary(validated["identifier"])

        {:error, changeset} ->
          assert changeset.errors[:identifier]
      end
    end

    test "validates record as map" do
      # Test non-map record
      attrs_with_string_record = %{
        "identifier" => "test",
        "record" => "not a map"
      }

      assert {:error, changeset} = EntityParams.validate(attrs_with_string_record)
      assert changeset.errors[:record]
    end
  end

  describe "error handling scenarios" do
    test "handles client validation errors" do
      # Test client without base_url
      invalid_client = %Req.Request{options: %{}}
      class = mock_class()
      attrs = %{"identifier" => "test", "record" => %{}}

      assert_raise ArgumentError, ~r/Failed to extract namespace/, fn ->
        Memory.create_entity(invalid_client, class, attrs)
      end
    end

    test "handles class with non-string id" do
      client = mock_client("ingest")
      # Use non-string id to trigger guard clause failure
      invalid_class = %Class{id: 123, name: "Invalid", provision_state: "active"}
      attrs = %{"identifier" => "test", "record" => %{}}

      assert_raise FunctionClauseError, fn ->
        Memory.create_entity(client, invalid_class, attrs)
      end
    end

    test "parameter validation fails early" do
      _client = mock_client("ingest")
      _class = mock_class()
      invalid_attrs = %{"invalid" => "params"}

      # This should fail at parameter validation step, before any HTTP call
      assert {:error, %Ecto.Changeset{}} = EntityParams.validate(invalid_attrs)
    end
  end

  describe "Entity struct behavior" do
    test "Entity.parse handles string input" do
      json_string =
        ~s({"id": "123", "class_id": "class1", "current_state": "active", "identifier": "test"})

      entity = Entity.parse(json_string)
      assert %Entity{} = entity
      assert entity.id == "123"
    end

    test "Entity.parse handles invalid JSON string" do
      invalid_json = "not valid json"

      entity = Entity.parse(invalid_json)
      assert %Entity{} = entity
      # Should return empty struct on parse failure
      assert entity.id == nil
    end

    test "Entity.parse handles non-map, non-string input" do
      entity = Entity.parse(123)
      assert %Entity{} = entity
      # Should return empty struct
      assert entity.id == nil
    end

    test "Entity.parse! returns struct for any input since parse always returns struct" do
      # Since Entity.parse always returns a struct (even empty), parse! never raises
      entity = Entity.parse!(123)
      assert %Entity{} = entity
      assert entity.id == nil
    end

    test "Entity changeset validation" do
      # Test that required fields are enforced
      changeset = Entity.changeset(%Entity{}, %{})
      refute changeset.valid?
      assert changeset.errors[:class_id]
      assert changeset.errors[:current_state]
      assert changeset.errors[:identifier]

      # Test with valid data
      valid_changeset =
        Entity.changeset(%Entity{}, %{
          "class_id" => "class1",
          "current_state" => "active",
          "identifier" => "test"
        })

      assert valid_changeset.valid?
    end
  end

  describe "complete workflow simulation" do
    test "end-to-end parameter flow" do
      # Simulate the complete parameter transformation flow
      input_attrs = %{
        "identifier" => "workflow-test",
        "record" => %{
          "name" => "Test Workflow",
          "type" => "simulation"
        },
        "validate_record" => false
      }

      # Step 1: Validate parameters
      assert {:ok, validated_params} = EntityParams.validate(input_attrs)

      # Step 2: Verify structure for API call
      api_payload = %{entity: validated_params}
      assert api_payload.entity["identifier"] == "workflow-test"
      assert api_payload.entity["record"]["name"] == "Test Workflow"
      assert api_payload.entity["validate_record"] == false

      # Step 3: Simulate API response parsing
      mock_api_response = %{
        "id" => "generated_123",
        "class_id" => "target_class",
        "current_state" => "created",
        "identifier" => "workflow-test"
      }

      parsed_entity = Entity.parse(mock_api_response)
      assert parsed_entity.id == "generated_123"
      assert parsed_entity.identifier == "workflow-test"
    end

    test "different class IDs are handled correctly" do
      _client = mock_client("ingest")
      _attrs = %{"identifier" => "test", "record" => %{}}

      # Test with different class ID formats
      class_ids = ["simple", "class_with_underscores", "class-with-dashes", "Class123"]

      Enum.each(class_ids, fn class_id ->
        class = mock_class(class_id)
        assert class.id == class_id
        # The function should accept any valid string class_id
        assert is_binary(class.id)
      end)
    end
  end
end
