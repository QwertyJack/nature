defmodule HTTP do
  use HTTPoison.Base

  defp cookies_from_resp_headers(recv_headers) when is_list(recv_headers) do
    List.foldl(recv_headers, [], fn
      {"Set-Cookie", c}, acc -> [c|acc]
      _, acc -> acc
    end)
    |> Enum.map(&(
      :hackney_cookie.parse_cookie(&1)
      |> (fn
        [{cookie_name, cookie_value} | cookie_opts] ->
          { cookie_name, cookie_value, cookie_opts }
        _error -> nil
      end).()
    ))
    |> Enum.filter(&(not is_nil &1))
  end

  defp to_request_cookie(cookies) do
    cookies
    |> Enum.map(fn { cookie_name, cookie_value, _cookie_opts} ->
      cookie_name <> "=" <> cookie_value
    end)
    |> Enum.join("; ")
    |> (&("" == &1 && [] || [&1])).() # "" => [], "foo1=abc" => ["foo1=abc"]
  end

  def get(url, headers \\ [], options \\ [timeout: 50_000, recv_timeout: 50_000]) do
    options = options |> Keyword.put(:hackney, [cookie: (:ets.lookup :nature, :cookie)[:cookie] || []])
    case request(:get, url, "", headers, options) do
      {:ok, %HTTPoison.Response{status_code: code, headers: recv_headers}} when code in [301, 302, 303, 307] ->
        {_, location} = List.keyfind(recv_headers, "Location", 0)
        req_cookie = cookies_from_resp_headers(recv_headers) |> to_request_cookie()

        options = options
                      |> Keyword.put(:max_redirect, (options[:max_redirect] || 5) - 1)
                      |> Keyword.put(:hackney,
                                     [cookie: [options[:hackney][:cookie]|req_cookie]
                                     |> List.delete(nil)
                                     |> Enum.join("; ")
                                     ]) # add any new cookies along with the previous ones to the request
        :ets.insert(:nature, {:cookie, options[:hackney][:cookie]})
        get(location, headers, options)
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} -> body
      {_, %HTTPoison.Response{status_code: code}} when code in [500, 503] -> :http_fail
      {_, %HTTPoison.Response{status_code: code, body: body}} ->
        require Logger
        Logger.error "#{code}: #{body}"
        :http_fail
      {_, %HTTPoison.Error{id: id, reason: reason}} ->
        require Logger
        Logger.error "#{id}: #{reason}"
        :http_fail
    end
  end
end
