defmodule Nature.Util do
  require Logger

  def nthreads, do: 6
  def domain, do: "https://www.nature.com"

  @doc "HTTP GET wrapper, follow 30x and record cookie"
  def get(u, cnt \\ 0)
  def get(_, 10), do: :http_fail
  def get(u, cnt) do
    try do
      HTTP.get u
    rescue
      HTTPoison.Error ->
        cnt = cnt + 1
        Logger.debug "HTTP fail #{cnt} times, retry ... #{u}"
        :timer.sleep 100
        get(u, cnt)
    end
  end

  @doc "Get meta of `cmd`"
  def mget(page, cmd) do
    page
    |> Meeseeks.one(cmd)
    |> Meeseeks.attr("content")
  end

  @doc "Get metas of `cmd`"
  def mgets(page, cmd) do
    page
    |> Meeseeks.all(cmd)
    |> Enum.map(&(Meeseeks.attr(&1, "content")))
  end

end
