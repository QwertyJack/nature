defmodule Nature.Paper do
  use Ecto.Schema

  schema "paper" do
    field(:link, :string)
    field(:subject, :string)
    field(:title, :string)
    field(:auths, {:array, :string})
    field(:from, :string)
    field(:doi, :string)
    field(:labels, {:array, :string})
    field(:date, :string)
    field(:abstract, :string)

    timestamps()
  end

  @limit 1000
  require Logger
  import Ecto.Query
  import Meeseeks.XPath

  alias Nature.Repo
  import Nature.Util

  defp _mget(page, cmd) do
    page
    |> Meeseeks.one(cmd)
    |> Meeseeks.attr("content")
  end

  defp _mgets(page, cmd) do
    page
    |> Meeseeks.all(cmd)
    |> Enum.map(&(Meeseeks.attr(&1, "content")))
  end

  defp _goto(paper) do
    Logger.info "Crawling paper at #{paper.link}"
    page = paper.link |> get

    title = page |> _mget(xpath("//meta[@name='dc.title']"))
    auths = page |> _mgets(xpath("//meta[@name='dc.creator']"))
    from = page |> _mget(xpath("//meta[@name='prism.publicationName']"))
    doi = page |> _mget(xpath("//meta[@name='DOI']"))
    labels = page |> _mget(xpath("//meta[@name='WT.z_subject_term']")) |> String.split(";")
    date = page |> _mget(xpath("//meta[@name='dc.date']"))
    abstract = page |> _mget(xpath("//meta[@name='dc.description']")) |> String.replace(~r/(\r|\n)\s+\+/, "")

    Repo.get_by(Nature.Paper, link: paper.link)
    |> Ecto.Changeset.change(
      title: title,
      auths: auths,
      from: from,
      doi: doi,
      labels: labels,
      date: date,
      abstract: abstract,
    )
    |> Repo.update!
    Logger.info "Done paper: #{paper.link}"
  end

  def main(subs \\ ["Chemistry"]) do
    papers = Repo.all(from p in Nature.Paper, where: (p.labels == type(^[], {:array, :string}) and p.subject in ^subs), limit: @limit)

    case papers do
      [] -> 
        Logger.info "Jobs #{subs} all done."
      _ -> 
        cnt = div(length(papers) - 1, nthreads()) + 1
        papers
        |> Enum.chunk(cnt, cnt, [])
        |> Enum.map(&Task.async(fn ->
          &1
          |> Enum.each(fn paper ->
            _goto(paper)
          end)
        end))
        |> Enum.map(&Task.await(&1, :infinity))
        main(subs)
    end
  end
end
