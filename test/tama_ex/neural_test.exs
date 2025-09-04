defmodule TamaEx.NeuralTest do
  use ExUnit.Case
  # Disable doctests due to undefined client variable in examples
  # doctest TamaEx.Neural

  alias TamaEx.Neural
  alias TamaEx.Neural.Space
  alias TamaEx.Neural.Class
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

  # Test helper for creating a mock client
  defp mock_client(namespace) do
    TamaEx.client(base_url: "https://api.example.com/#{namespace}")
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
    end
  end
end
