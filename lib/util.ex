defmodule Nature.Util do
  require Logger

  def nthreads, do: 6
  def domain, do: "https://www.nature.com"

  @doc "HTTP GET wrapper"
  def http_get(u, cnt \\ 0)
  def http_get(u, 10), do: :http_fail
  def http_get(u, cnt) do
    try do
      resp = HTTPoison.get!(u)
      case resp.status_code do
        500 -> :http_fail
        _ -> resp
      end
    rescue
      HTTPoison.Error ->
        cnt = cnt + 1
        Logger.debug "HTTP fail #{cnt} times, retry ... #{u}"
        :timer.sleep 100
        http_get(u, cnt)
    end
  end

  @doc "Visit nature.com, follow 30x until the end"
  def get(u) do
    resp = http_get(u)
    case resp do
      :http_fail -> :http_fail
      _ ->
        resp.headers
        |> Enum.filter(fn({k, _}) -> k == "Location" end)
        |> case do
          [] -> resp.body
          [h] -> elem(h, 1) |> get()
        end
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
