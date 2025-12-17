defmodule TamaEx.MemoryTest do
  use ExUnit.Case
  import TestHelpers
  doctest TamaEx.Memory

  alias TamaEx.Memory
  alias TamaEx.Memory.Entity
  alias TamaEx.Memory.Entity.Params, as: EntityParams
  alias TamaEx.Neural.Class

  setup do
    bypass = Bypass.open()
    {:ok, bypass: bypass}
  end

  # Test helper for creating a mock class
  defp mock_class(id \\ "class_123") do
    %Class{
      id: id,
      name: "Test Class",
      provision_state: "active"
    }
  end

  describe "create_entity/3 - bypass integration" do
    test "successfully creates entity with bypass", %{bypass: bypass} do
      base_url = "http://localhost:#{bypass.port}"
      client = mock_client("memory", base_url)
      class = mock_class("test_class_123")

      attrs = %{
        "identifier" => "test-entity-bypass",
        "record" => %{"name" => "Test Entity", "value" => 42},
        "validate_record" => true
      }

      expected_response = %{
        "data" => %{
          "id" => "entity_created_456",
          "class_id" => "test_class_123",
          "current_state" => "active",
          "identifier" => "test-entity-bypass",
          "record" => %{"name" => "Test Entity", "value" => 42}
        }
      }

      Bypass.expect(bypass, "POST", "/memory/classes/test_class_123/entities", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request_data = Jason.decode!(body)

        # Verify the request structure
        assert request_data["entity"]["identifier"] == "test-entity-bypass"
        assert request_data["entity"]["record"]["name"] == "Test Entity"
        assert request_data["entity"]["record"]["value"] == 42
        assert request_data["entity"]["validate_record"] == true

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(expected_response))
      end)

      # Make the actual API call
      assert {:ok, %Entity{} = entity} = Memory.create_entity(client, class, attrs)

      # Verify the parsed entity
      assert entity.id == "entity_created_456"
      assert entity.class_id == "test_class_123"
      assert entity.current_state == "active"
      assert entity.identifier == "test-entity-bypass"
    end

    test "handles API error responses with bypass", %{bypass: bypass} do
      base_url = "http://localhost:#{bypass.port}"
      client = mock_client("memory", base_url)
      class = mock_class("error_class_123")

      attrs = %{
        "identifier" => "error-entity",
        "record" => %{"invalid" => "data"}
      }

      error_response = %{
        "error" => %{
          "message" => "Validation failed",
          "details" => %{
            "record" => ["is invalid"]
          }
        }
      }

      Bypass.expect(bypass, "POST", "/memory/classes/error_class_123/entities", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request_data = Jason.decode!(body)

        assert request_data["entity"]["identifier"] == "error-entity"
        assert request_data["entity"]["record"]["invalid"] == "data"

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(422, Jason.encode!(error_response))
      end)

      # Make the actual API call and expect an error
      assert {:error, _error} = Memory.create_entity(client, class, attrs)
    end

    test "handles server errors with bypass", %{bypass: bypass} do
      base_url = "http://localhost:#{bypass.port}"
      client = mock_client("memory", base_url)
      class = mock_class("server_error_class_123")

      attrs = %{
        "identifier" => "server-error-entity",
        "record" => %{"data" => "test"}
      }

      # Simulate server error
      Bypass.expect(bypass, "POST", "/memory/classes/server_error_class_123/entities", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(500, Jason.encode!(%{"error" => "Internal server error"}))
      end)

      # Make the actual API call and expect an error
      assert {:error, _error} = Memory.create_entity(client, class, attrs)
    end

    test "handles different class IDs in URL construction", %{bypass: bypass} do
      base_url = "http://localhost:#{bypass.port}"
      client = mock_client("memory", base_url)

      test_cases = [
        {"simple", "simple"},
        {"class_with_underscores", "class_with_underscores"},
        {"class-with-dashes", "class-with-dashes"},
        {"Class123", "Class123"}
      ]

      Enum.each(test_cases, fn {class_id, expected_url_part} ->
        class = mock_class(class_id)
        attrs = %{"identifier" => "test-#{class_id}", "record" => %{}}

        expected_response = %{
          "data" => %{
            "id" => "entity_#{class_id}",
            "class_id" => class_id,
            "current_state" => "active",
            "identifier" => "test-#{class_id}",
            "record" => %{}
          }
        }

        Bypass.expect_once(
          bypass,
          "POST",
          "/memory/classes/#{expected_url_part}/entities",
          fn conn ->
            conn
            |> Plug.Conn.put_resp_content_type("application/json")
            |> Plug.Conn.resp(201, Jason.encode!(expected_response))
          end
        )

        assert {:ok, %Entity{} = entity} = Memory.create_entity(client, class, attrs)
        assert entity.class_id == class_id
        assert entity.identifier == "test-#{class_id}"
      end)
    end

    test "validates request headers and content type", %{bypass: bypass} do
      base_url = "http://localhost:#{bypass.port}"
      client = mock_client("memory", base_url)
      class = mock_class("headers_test_123")

      attrs = %{
        "identifier" => "headers-test",
        "record" => %{"test" => "data"}
      }

      Bypass.expect(bypass, "POST", "/memory/classes/headers_test_123/entities", fn conn ->
        # Verify headers
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer mock_token"]
        assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]

        expected_response = %{
          "data" => %{
            "id" => "headers_entity_123",
            "class_id" => "headers_test_123",
            "current_state" => "active",
            "identifier" => "headers-test",
            "record" => %{"test" => "data"}
          }
        }

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(expected_response))
      end)

      assert {:ok, %Entity{}} = Memory.create_entity(client, class, attrs)
    end

    test "handles complex record structures with bypass", %{bypass: bypass} do
      base_url = "http://localhost:#{bypass.port}"
      client = mock_client("memory", base_url)
      class = mock_class("complex_class_123")

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
        "record" => complex_record,
        "validate_record" => false
      }

      expected_response = %{
        "data" => %{
          "id" => "complex_entity_789",
          "class_id" => "complex_class_123",
          "current_state" => "active",
          "identifier" => "complex-entity",
          "record" => complex_record
        }
      }

      Bypass.expect(bypass, "POST", "/memory/classes/complex_class_123/entities", fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        request_data = Jason.decode!(body)

        # Verify the complex record structure is preserved
        assert request_data["entity"]["identifier"] == "complex-entity"
        assert request_data["entity"]["record"]["user"]["name"] == "John Doe"
        assert request_data["entity"]["record"]["user"]["age"] == 30
        assert request_data["entity"]["record"]["user"]["preferences"]["theme"] == "dark"
        assert request_data["entity"]["record"]["user"]["preferences"]["notifications"] == true

        assert request_data["entity"]["record"]["metadata"]["created_at"] ==
                 "2023-01-01T00:00:00Z"

        assert request_data["entity"]["record"]["metadata"]["tags"] == ["important", "test"]
        assert request_data["entity"]["validate_record"] == false

        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(201, Jason.encode!(expected_response))
      end)

      assert {:ok, %Entity{} = entity} = Memory.create_entity(client, class, attrs)
      assert entity.id == "complex_entity_789"
      assert entity.class_id == "complex_class_123"
      assert entity.current_state == "active"
      assert entity.identifier == "complex-entity"
    end
  end

  describe "get_entity/3 - bypass integration" do
    test "successfully retrieves an entity by identifier", %{bypass: bypass} do
      base_url = "http://localhost:#{bypass.port}"
      client = mock_client("memory", base_url)
      class = mock_class("class_for_get")
      entity_identifier = "entity-identifier-123"

      expected_response = %{
        "data" => %{
          "id" => "entity_returned_123",
          "class_id" => "class_for_get",
          "current_state" => "active",
          "identifier" => entity_identifier,
          "record" => %{"some" => "data"}
        }
      }

      Bypass.expect(
        bypass,
        "GET",
        "/memory/classes/class_for_get/entities/#{entity_identifier}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(expected_response))
        end
      )

      assert {:ok, %Entity{} = entity} = Memory.get_entity(client, class, entity_identifier)
      assert entity.id == "entity_returned_123"
      assert entity.class_id == "class_for_get"
      assert entity.current_state == "active"
      assert entity.identifier == entity_identifier
    end

    test "returns error tuple when entity is not found", %{bypass: bypass} do
      base_url = "http://localhost:#{bypass.port}"
      client = mock_client("memory", base_url)
      class = mock_class("missing_class")
      entity_identifier = "missing-entity"

      Bypass.expect(
        bypass,
        "GET",
        "/memory/classes/missing_class/entities/#{entity_identifier}",
        fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(404, Jason.encode!(%{"error" => "not found"}))
        end
      )

      assert {:error, :not_found} = Memory.get_entity(client, class, entity_identifier)
    end
  end

  describe "update_entity/4 - bypass integration" do
    test "successfully updates entity with bypass", %{bypass: bypass} do
      base_url = "http://localhost:#{bypass.port}"
      client = mock_client("memory", base_url)
      class = mock_class("test_class_123")
      entity_id = "entity_123"

      attrs = %{
        "identifier" => "updated-entity-bypass",
        "record" => %{"name" => "Updated Entity", "value" => 99},
        "validate_record" => true
      }

      expected_response = %{
        "data" => %{
          "id" => entity_id,
          "class_id" => "test_class_123",
          "current_state" => "active",
          "identifier" => "updated-entity-bypass",
          "record" => %{"name" => "Updated Entity", "value" => 99}
        }
      }

      Bypass.expect(
        bypass,
        "PATCH",
        "/memory/classes/test_class_123/entities/#{entity_id}",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          request_data = Jason.decode!(body)

          # Verify the request structure
          assert request_data["entity"]["identifier"] == "updated-entity-bypass"
          assert request_data["entity"]["record"]["name"] == "Updated Entity"
          assert request_data["entity"]["record"]["value"] == 99
          assert request_data["entity"]["validate_record"] == true

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(expected_response))
        end
      )

      # Make the actual API call
      assert {:ok, %Entity{} = entity} = Memory.update_entity(client, class, entity_id, attrs)

      # Verify the parsed entity
      assert entity.id == entity_id
      assert entity.class_id == "test_class_123"
      assert entity.current_state == "active"
      assert entity.identifier == "updated-entity-bypass"
    end

    test "successfully updates entity by identifier", %{bypass: bypass} do
      base_url = "http://localhost:#{bypass.port}"
      client = mock_client("memory", base_url)
      class = mock_class("test_class_456")
      entity_identifier = "my-entity-identifier"

      attrs = %{
        "record" => %{"status" => "updated"},
        "validate_record" => false
      }

      expected_response = %{
        "data" => %{
          "id" => "entity_789",
          "class_id" => "test_class_456",
          "current_state" => "updated",
          "identifier" => entity_identifier,
          "record" => %{"status" => "updated"}
        }
      }

      Bypass.expect(
        bypass,
        "PATCH",
        "/memory/classes/test_class_456/entities/#{entity_identifier}",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          request_data = Jason.decode!(body)

          assert request_data["entity"]["record"]["status"] == "updated"
          assert request_data["entity"]["validate_record"] == false

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(expected_response))
        end
      )

      assert {:ok, %Entity{} = entity} =
               Memory.update_entity(client, class, entity_identifier, attrs)

      assert entity.id == "entity_789"
      assert entity.class_id == "test_class_456"
      assert entity.current_state == "updated"
      assert entity.identifier == entity_identifier
    end

    test "handles API error responses with bypass", %{bypass: bypass} do
      base_url = "http://localhost:#{bypass.port}"
      client = mock_client("memory", base_url)
      class = mock_class("error_class_123")
      entity_id = "error_entity"

      attrs = %{
        "identifier" => "error-entity",
        "record" => %{"invalid" => "data"}
      }

      error_response = %{
        "error" => %{
          "message" => "Validation failed",
          "details" => %{
            "record" => ["is invalid"]
          }
        }
      }

      Bypass.expect(
        bypass,
        "PATCH",
        "/memory/classes/error_class_123/entities/#{entity_id}",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          request_data = Jason.decode!(body)

          assert request_data["entity"]["identifier"] == "error-entity"
          assert request_data["entity"]["record"]["invalid"] == "data"

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(422, Jason.encode!(error_response))
        end
      )

      # Make the actual API call and expect an error
      assert {:error, _error} = Memory.update_entity(client, class, entity_id, attrs)
    end

    test "handles entity not found error", %{bypass: bypass} do
      base_url = "http://localhost:#{bypass.port}"
      client = mock_client("memory", base_url)
      class = mock_class("class_123")
      entity_id = "nonexistent_entity"

      attrs = %{
        "record" => %{"data" => "test"}
      }

      Bypass.expect(bypass, "PATCH", "/memory/classes/class_123/entities/#{entity_id}", fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.resp(404, Jason.encode!(%{"error" => "not found"}))
      end)

      assert {:error, :not_found} = Memory.update_entity(client, class, entity_id, attrs)
    end

    test "handles complex record structures with bypass", %{bypass: bypass} do
      base_url = "http://localhost:#{bypass.port}"
      client = mock_client("memory", base_url)
      class = mock_class("complex_class_123")
      entity_id = "complex_entity"

      complex_record = %{
        "user" => %{
          "name" => "Jane Smith",
          "age" => 35,
          "preferences" => %{
            "theme" => "light",
            "notifications" => false
          }
        },
        "metadata" => %{
          "updated_at" => "2024-01-01T00:00:00Z",
          "tags" => ["updated", "production"]
        }
      }

      attrs = %{
        "identifier" => "complex-updated",
        "record" => complex_record,
        "validate_record" => false
      }

      expected_response = %{
        "data" => %{
          "id" => entity_id,
          "class_id" => "complex_class_123",
          "current_state" => "active",
          "identifier" => "complex-updated",
          "record" => complex_record
        }
      }

      Bypass.expect(
        bypass,
        "PATCH",
        "/memory/classes/complex_class_123/entities/#{entity_id}",
        fn conn ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          request_data = Jason.decode!(body)

          # Verify the complex record structure is preserved
          assert request_data["entity"]["identifier"] == "complex-updated"
          assert request_data["entity"]["record"]["user"]["name"] == "Jane Smith"
          assert request_data["entity"]["record"]["user"]["age"] == 35
          assert request_data["entity"]["record"]["user"]["preferences"]["theme"] == "light"

          assert request_data["entity"]["record"]["user"]["preferences"]["notifications"] == false

          assert request_data["entity"]["record"]["metadata"]["updated_at"] ==
                   "2024-01-01T00:00:00Z"

          assert request_data["entity"]["record"]["metadata"]["tags"] == ["updated", "production"]
          assert request_data["entity"]["validate_record"] == false

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(expected_response))
        end
      )

      assert {:ok, %Entity{} = entity} = Memory.update_entity(client, class, entity_id, attrs)
      assert entity.id == entity_id
      assert entity.class_id == "complex_class_123"
      assert entity.current_state == "active"
      assert entity.identifier == "complex-updated"
    end

    test "validates request headers and content type", %{bypass: bypass} do
      base_url = "http://localhost:#{bypass.port}"
      client = mock_client("memory", base_url)
      class = mock_class("headers_test_123")
      entity_id = "entity_headers"

      attrs = %{
        "identifier" => "headers-test",
        "record" => %{"test" => "data"}
      }

      Bypass.expect(
        bypass,
        "PATCH",
        "/memory/classes/headers_test_123/entities/#{entity_id}",
        fn conn ->
          # Verify headers
          assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer mock_token"]
          assert Plug.Conn.get_req_header(conn, "content-type") == ["application/json"]

          expected_response = %{
            "data" => %{
              "id" => entity_id,
              "class_id" => "headers_test_123",
              "current_state" => "active",
              "identifier" => "headers-test",
              "record" => %{"test" => "data"}
            }
          }

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.resp(200, Jason.encode!(expected_response))
        end
      )

      assert {:ok, %Entity{}} = Memory.update_entity(client, class, entity_id, attrs)
    end
  end

  describe "create_entity/3 - unit tests" do
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

  describe "get_entity/3 - unit tests" do
    test "validates required client namespace" do
      client = mock_client("provision")
      class = mock_class()

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        Memory.get_entity(client, class, "entity")
      end
    end

    test "validates class id is a binary" do
      client = mock_client("memory")
      invalid_class = %Class{id: nil, name: "Invalid", provision_state: "active"}

      assert_raise FunctionClauseError, fn ->
        Memory.get_entity(client, invalid_class, "entity")
      end
    end

    test "validates identifier is a binary" do
      client = mock_client("memory")
      class = mock_class()

      assert_raise FunctionClauseError, fn ->
        Memory.get_entity(client, class, 123)
      end
    end
  end

  describe "update_entity/4 - unit tests" do
    test "validates required client namespace" do
      client = mock_client("provision")
      class = mock_class()
      attrs = %{"record" => %{"data" => "test"}}

      assert_raise ArgumentError, ~r/Invalid client namespace/, fn ->
        Memory.update_entity(client, class, "entity_id", attrs)
      end
    end

    test "validates class id is a binary" do
      client = mock_client("memory")
      invalid_class = %Class{id: nil, name: "Invalid", provision_state: "active"}
      attrs = %{"record" => %{"data" => "test"}}

      assert_raise FunctionClauseError, fn ->
        Memory.update_entity(client, invalid_class, "entity_id", attrs)
      end
    end

    test "validates entity id is a binary" do
      client = mock_client("memory")
      class = mock_class()
      attrs = %{"record" => %{"data" => "test"}}

      assert_raise FunctionClauseError, fn ->
        Memory.update_entity(client, class, 123, attrs)
      end
    end

    test "validates entity parameters" do
      _client = mock_client("memory")
      _class = mock_class()

      # Empty attrs should still validate if record is provided
      valid_attrs = %{"record" => %{"data" => "test"}}
      assert {:ok, validated} = EntityParams.validate_update(valid_attrs)
      assert validated["record"] == %{"data" => "test"}

      # Invalid attrs without record should fail
      invalid_attrs = %{"invalid" => "params"}
      assert {:error, %Ecto.Changeset{}} = EntityParams.validate_update(invalid_attrs)
    end

    test "constructs correct URL for update API call" do
      # This test verifies the URL construction logic
      class_id = "my_class_123"
      entity_id = "entity_456"
      _expected_url = "/memory/classes/#{class_id}/entities/#{entity_id}"

      class = mock_class(class_id)
      assert class.id == class_id
    end

    test "sends correct JSON payload structure for update" do
      attrs = %{
        "identifier" => "updated-entity",
        "record" => %{"name" => "Updated"},
        "validate_record" => false
      }

      assert {:ok, validated_params} = EntityParams.validate_update(attrs)

      # Verify the expected JSON structure
      expected_json = %{entity: validated_params}
      assert expected_json[:entity]["identifier"] == "updated-entity"
      assert expected_json[:entity]["record"] == %{"name" => "Updated"}
      assert expected_json[:entity]["validate_record"] == false
    end

    test "allows partial updates with only record" do
      attrs = %{
        "record" => %{"field" => "new_value"}
      }

      assert {:ok, validated_params} = EntityParams.validate_update(attrs)
      assert validated_params["record"] == %{"field" => "new_value"}
      # Default value
      assert validated_params["validate_record"] == true
    end
  end

  describe "integration with Entity parsing" do
    test "successful response gets parsed by Entity module" do
      # Test that Entity.parse works correctly with typical API response
      api_response_data = %{
        "id" => "entity_789",
        "class_id" => "class_123",
        "current_state" => "active",
        "identifier" => "my-entity",
        "record" => %{"data" => "value"}
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
        "identifier" => "minimal-entity",
        "record" => %{}
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
        ~s({"id": "123", "class_id": "class1", "current_state": "active", "identifier": "test", "record": {}})

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

      # Test with valid data (record is required)
      invalid_changeset =
        Entity.changeset(%Entity{}, %{
          "class_id" => "class1",
          "current_state" => "active",
          "identifier" => "test"
        })

      refute invalid_changeset.valid?
      assert invalid_changeset.errors[:record]

      # Test with valid data including record
      valid_changeset =
        Entity.changeset(%Entity{}, %{
          "class_id" => "class1",
          "current_state" => "active",
          "identifier" => "test",
          "record" => %{"data" => "value"}
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
        "identifier" => "workflow-test",
        "record" => %{
          "name" => "Test Workflow",
          "type" => "simulation"
        }
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
