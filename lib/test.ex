defmodule A do

  @entry "https://www.nature.com/subjects"
  @cookie "/dev/shm/nature/cookie"

  def curl(u) do
    case System.cmd("curl", ["-sSL", "-b", @cookie, "-c", @cookie, u]) do
      {ret, 0} -> ret
    end
  end

  def test, do: curl @entry
end
