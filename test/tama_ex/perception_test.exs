defmodule TamaEx.PerceptionTest do
  use ExUnit.Case
  doctest TamaEx.Perception

  alias TamaEx.Perception
  alias TamaEx.Perception.Chain
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
end
