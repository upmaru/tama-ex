defmodule TamaTest do
  use ExUnit.Case
  doctest Tama

  test "greets the world" do
    assert Tama.hello() == :world
  end
end
