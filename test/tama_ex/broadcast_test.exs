defmodule TamaEx.BroadcastTest do
  use ExUnit.Case, async: true
  alias TamaEx.Broadcast

  describe "changeset/2" do
    test "validates a complete broadcast payload" do
      valid_attrs = %{
        event: %{
          name: "step.updated",
          domain: "workflow",
          metadata: %{
            changes: %{"state" => "processing"},
            comment: "Step is now processing",
            parameters: %{"timeout" => 300}
          }
        },
        step: %{
          id: "550e8400-e29b-41d4-a716-446655440001",
          current_state: "processing",
          index: 1,
          attempt: 1,
          concepts: [
            %{
              id: "550e8400-e29b-41d4-a716-446655440002",
              relation: "input",
              content: %{"content" => "some content"}
            },
            %{
              id: "550e8400-e29b-41d4-a716-446655440003",
              relation: "output",
              content: %{"content" => "result content"}
            }
          ],
          thought: %{
            chain: %{
              id: "550e8400-e29b-41d4-a716-446655440004",
              name: "main_chain"
            },
            relation: "primary",
            index: 0
          },
          branch: %{
            id: "550e8400-e29b-41d4-a716-446655440005",
            chain_id: "550e8400-e29b-41d4-a716-446655440004",
            current_state: "active",
            flow: %{
              id: "550e8400-e29b-41d4-a716-446655440006",
              origin_entity: %{
                id: "550e8400-e29b-41d4-a716-446655440007",
                current_state: "ready",
                identifier: "entity_abc"
              }
            }
          }
        }
      }

      changeset = Broadcast.changeset(%Broadcast{}, valid_attrs)

      assert changeset.valid?

      broadcast = Ecto.Changeset.apply_changes(changeset)

      # Test event fields
      assert broadcast.event.name == "step.updated"
      assert broadcast.event.domain == "workflow"
      assert broadcast.event.metadata.changes == %{"state" => "processing"}
      assert broadcast.event.metadata.comment == "Step is now processing"
      assert broadcast.event.metadata.parameters == %{"timeout" => 300}

      # Test step fields
      assert broadcast.step.id == "550e8400-e29b-41d4-a716-446655440001"
      assert broadcast.step.current_state == "processing"
      assert broadcast.step.index == 1
      assert broadcast.step.attempt == 1

      # Test concepts
      assert length(broadcast.step.concepts) == 2
      assert Enum.at(broadcast.step.concepts, 0).id == "550e8400-e29b-41d4-a716-446655440002"
      assert Enum.at(broadcast.step.concepts, 0).relation == "input"
      assert Enum.at(broadcast.step.concepts, 0).content == %{"content" => "some content"}

      # Test thought and chain
      assert broadcast.step.thought.relation == "primary"
      assert broadcast.step.thought.index == 0
      assert broadcast.step.thought.chain.id == "550e8400-e29b-41d4-a716-446655440004"
      assert broadcast.step.thought.chain.name == "main_chain"

      # Test branch and flow
      assert broadcast.step.branch.id == "550e8400-e29b-41d4-a716-446655440005"
      assert broadcast.step.branch.chain_id == "550e8400-e29b-41d4-a716-446655440004"
      assert broadcast.step.branch.current_state == "active"
      assert broadcast.step.branch.flow.id == "550e8400-e29b-41d4-a716-446655440006"
      assert broadcast.step.branch.flow.origin_entity.id == "550e8400-e29b-41d4-a716-446655440007"
      assert broadcast.step.branch.flow.origin_entity.current_state == "ready"
      assert broadcast.step.branch.flow.origin_entity.identifier == "entity_abc"
    end

    test "validates with minimal required fields" do
      minimal_attrs = %{
        event: %{
          name: "step.created",
          domain: "workflow",
          metadata: %{
            changes: %{},
            comment: nil,
            parameters: %{}
          }
        },
        step: %{
          id: "550e8400-e29b-41d4-a716-446655440010",
          current_state: "pending",
          index: 0,
          attempt: 1,
          concepts: [],
          thought: %{
            chain: %{
              id: "550e8400-e29b-41d4-a716-446655440011",
              name: "default_chain"
            },
            relation: "root",
            index: 0
          },
          branch: %{
            id: "550e8400-e29b-41d4-a716-446655440012",
            chain_id: "550e8400-e29b-41d4-a716-446655440011",
            current_state: "initialized",
            flow: %{
              id: "550e8400-e29b-41d4-a716-446655440013",
              origin_entity: %{
                id: "550e8400-e29b-41d4-a716-446655440014",
                current_state: "created",
                identifier: "entity_001"
              }
            }
          }
        }
      }

      changeset = Broadcast.changeset(%Broadcast{}, minimal_attrs)

      assert changeset.valid?

      broadcast = Ecto.Changeset.apply_changes(changeset)

      assert broadcast.event.name == "step.created"
      assert broadcast.step.concepts == []
      assert broadcast.step.thought.chain.name == "default_chain"
    end

    test "validates with empty event and step" do
      empty_attrs = %{
        event: %{},
        step: %{}
      }

      changeset = Broadcast.changeset(%Broadcast{}, empty_attrs)

      # Should still be valid as all fields are optional in our current schema
      assert changeset.valid?
    end

    test "validates with nil metadata fields" do
      attrs_with_nils = %{
        event: %{
          name: "step.failed",
          domain: "workflow",
          metadata: %{
            changes: nil,
            comment: nil,
            parameters: nil
          }
        },
        step: %{
          id: "550e8400-e29b-41d4-a716-446655440020",
          current_state: "failed",
          index: 5,
          attempt: 3,
          concepts: [],
          thought: %{
            chain: %{
              id: "550e8400-e29b-41d4-a716-446655440021",
              name: "error_chain"
            },
            relation: "error",
            index: 1
          },
          branch: %{
            id: "550e8400-e29b-41d4-a716-446655440022",
            chain_id: "550e8400-e29b-41d4-a716-446655440021",
            current_state: "error",
            flow: %{
              id: "550e8400-e29b-41d4-a716-446655440023",
              origin_entity: %{
                id: "550e8400-e29b-41d4-a716-446655440024",
                current_state: "failed",
                identifier: "failed_entity"
              }
            }
          }
        }
      }

      changeset = Broadcast.changeset(%Broadcast{}, attrs_with_nils)

      assert changeset.valid?

      broadcast = Ecto.Changeset.apply_changes(changeset)

      assert broadcast.event.metadata.changes == nil
      assert broadcast.event.metadata.comment == nil
      assert broadcast.event.metadata.parameters == nil
    end

    test "validates with multiple concepts" do
      attrs_with_many_concepts = %{
        event: %{
          name: "step.processing",
          domain: "analysis",
          metadata: %{
            changes: %{"concepts" => "added"},
            comment: "Multiple concepts processed",
            parameters: %{"batch_size" => 10}
          }
        },
        step: %{
          id: "550e8400-e29b-41d4-a716-446655440030",
          current_state: "analyzing",
          index: 3,
          attempt: 2,
          concepts: [
            %{
              id: "550e8400-e29b-41d4-a716-446655440031",
              relation: "input",
              content: %{"content" => "first input"}
            },
            %{
              id: "550e8400-e29b-41d4-a716-446655440032",
              relation: "processing",
              content: %{"content" => "intermediate result"}
            },
            %{
              id: "550e8400-e29b-41d4-a716-446655440033",
              relation: "output",
              content: %{"content" => "final output"}
            },
            %{
              id: "550e8400-e29b-41d4-a716-446655440034",
              relation: "metadata",
              content: %{"content" => "process metadata"}
            }
          ],
          thought: %{
            chain: %{
              id: "550e8400-e29b-41d4-a716-446655440035",
              name: "analysis_chain"
            },
            relation: "analytical",
            index: 2
          },
          branch: %{
            id: "550e8400-e29b-41d4-a716-446655440036",
            chain_id: "550e8400-e29b-41d4-a716-446655440035",
            current_state: "processing",
            flow: %{
              id: "550e8400-e29b-41d4-a716-446655440037",
              origin_entity: %{
                id: "550e8400-e29b-41d4-a716-446655440038",
                current_state: "active",
                identifier: "analysis_entity"
              }
            }
          }
        }
      }

      changeset = Broadcast.changeset(%Broadcast{}, attrs_with_many_concepts)

      assert changeset.valid?

      broadcast = Ecto.Changeset.apply_changes(changeset)

      assert length(broadcast.step.concepts) == 4

      concepts = broadcast.step.concepts
      assert Enum.at(concepts, 0).relation == "input"
      assert Enum.at(concepts, 1).relation == "processing"
      assert Enum.at(concepts, 2).relation == "output"
      assert Enum.at(concepts, 3).relation == "metadata"
    end
  end

  describe "parse/1" do
    test "successfully parses valid broadcast data" do
      valid_attrs = %{
        event: %{
          name: "step.updated",
          domain: "workflow",
          metadata: %{
            changes: %{"state" => "processing"},
            comment: "Step is now processing",
            parameters: %{"timeout" => 300}
          }
        },
        step: %{
          id: "550e8400-e29b-41d4-a716-446655440040",
          current_state: "processing",
          index: 1,
          attempt: 1,
          concepts: [
            %{
              id: "550e8400-e29b-41d4-a716-446655440041",
              relation: "input",
              content: %{"content" => "some content"}
            }
          ],
          thought: %{
            chain: %{
              id: "550e8400-e29b-41d4-a716-446655440042",
              name: "main_chain"
            },
            relation: "primary",
            index: 0
          },
          branch: %{
            id: "550e8400-e29b-41d4-a716-446655440043",
            chain_id: "550e8400-e29b-41d4-a716-446655440042",
            current_state: "active",
            flow: %{
              id: "550e8400-e29b-41d4-a716-446655440044",
              origin_entity: %{
                id: "550e8400-e29b-41d4-a716-446655440045",
                current_state: "ready",
                identifier: "entity_abc"
              }
            }
          }
        }
      }

      assert {:ok, broadcast} = Broadcast.parse(valid_attrs)
      assert broadcast.event.name == "step.updated"
      assert broadcast.step.id == "550e8400-e29b-41d4-a716-446655440040"
      assert broadcast.step.thought.chain.name == "main_chain"
    end

    test "successfully parses minimal broadcast data" do
      minimal_attrs = %{
        event: %{
          name: "step.created",
          domain: "workflow",
          metadata: %{
            changes: %{},
            comment: nil,
            parameters: %{}
          }
        },
        step: %{
          id: "550e8400-e29b-41d4-a716-446655440050",
          current_state: "pending",
          index: 0,
          attempt: 1,
          concepts: [],
          thought: %{
            chain: %{
              id: "550e8400-e29b-41d4-a716-446655440051",
              name: "default_chain"
            },
            relation: "root",
            index: 0
          },
          branch: %{
            id: "550e8400-e29b-41d4-a716-446655440052",
            chain_id: "550e8400-e29b-41d4-a716-446655440051",
            current_state: "initialized",
            flow: %{
              id: "550e8400-e29b-41d4-a716-446655440053",
              origin_entity: %{
                id: "550e8400-e29b-41d4-a716-446655440054",
                current_state: "created",
                identifier: "entity_001"
              }
            }
          }
        }
      }

      assert {:ok, broadcast} = Broadcast.parse(minimal_attrs)
      assert broadcast.event.name == "step.created"
      assert broadcast.step.concepts == []
    end

    test "returns error for empty data due to required validations" do
      # Test with completely empty data - should fail since event and step are required
      assert {:error, changeset} = Broadcast.parse(%{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset)[:event]
      assert "can't be blank" in errors_on(changeset)[:step]
    end

    test "handles partial invalid data gracefully" do
      invalid_attrs = %{
        event: %{
          name: "step.test",
          domain: "workflow",
          metadata: %{
            changes: %{},
            comment: "test",
            parameters: %{}
          }
        },
        step: %{
          # Missing required nested structures will still be handled gracefully
          # since our schemas don't enforce required validations
          id: "550e8400-e29b-41d4-a716-446655440060",
          current_state: "test",
          index: 0,
          attempt: 1,
          concepts: []
        }
      }

      # This should still work since we don't have strict validations
      assert {:ok, broadcast} = Broadcast.parse(invalid_attrs)
      assert broadcast.event.name == "step.test"
      assert broadcast.step.id == "550e8400-e29b-41d4-a716-446655440060"
    end

    # Helper function to extract error messages from changeset
    defp errors_on(changeset) do
      Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
        Regex.replace(~r"%{(\w+)}", message, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)
    end
  end
end
