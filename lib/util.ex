defmodule Nature.Util do
  require Logger

  def nthreads, do: 6
  def url, do: "https://www.nature.com/subjects"
  def domain, do: "https://www.nature.com"

  @doc "HTTP GET wrapper"
  def http_get(u, follow \\ false, cnt \\ 0) do
    try do
      HTTPoison.get!(u, [], [follow_redirect: follow])
    rescue
      HTTPoison.Error ->
        cnt = cnt + 1
        Logger.debug "HTTP fail for #{cnt} times, retry ..."
        http_get(u, follow, cnt)
    end
  end

  @doc "Visit nature.com, 1st 303, then follow 302 until the end"
  def get(u) do
    ret = http_get(u, false).headers
          |> Enum.filter(fn({k, _}) -> k == "Location" end)
          |> hd
          |> elem(1)
          |> http_get(true)
    ret.body
  end
end
