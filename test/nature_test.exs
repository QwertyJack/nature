defmodule NatureTest do
  use ExUnit.Case
  doctest Nature

  @nproc 10

  test "greets the world" do
    assert Nature.hello() == :world
  end

end
