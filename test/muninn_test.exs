defmodule MuninnTest do
  use ExUnit.Case
  doctest Muninn

  test "greets the world" do
    assert Muninn.hello() == :world
  end
end
