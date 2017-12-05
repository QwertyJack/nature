defmodule Mix.Tasks.Get do
  use Mix.Task

  @shortdoc "Crawler papers under certain subject"
  def run(abbrev) do
    Mix.Task.run "app.start", []
    :erlang.apply(Nature.Paper, abbrev |> hd |> String.to_atom, [])
    |> Nature.Paper.main
  end
end
