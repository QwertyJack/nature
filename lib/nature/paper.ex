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
    field(:desc, :string)

    timestamps()
  end

  @limit 1000
  require Logger
  import Ecto.Query
  import Meeseeks.XPath

  alias Nature.Repo
  import Nature.Util

  defp _goto(paper, cnt \\ 0)
  defp _goto(paper, 5) do
    Repo.get_by(Nature.Paper, id: paper.id)
    |> Ecto.Changeset.change(doi: "")
    |> Repo.update!
    Logger.info "Paper fail: #{paper.id}"
  end
  defp _goto(paper, cnt) do
    try do
      Logger.info "Paper #{paper.link}"
      page = paper.link |> get

      if page == :http_fail do
        Logger.error "Paper wrong: #{paper.id}"
      end

      title =     page |> mget(xpath("//meta[@name='dc.title']"))
      auths =     page |> mgets(xpath("//meta[@name='dc.creator']"))
      from =      page |> mget(xpath("//meta[@name='prism.publicationName']"))
      doi =       page |> mget(xpath("//meta[@name='DOI']"))
      labels =    page |> mget(xpath("//meta[@name='WT.z_subject_term']")) |> String.split(";")
      date =      page |> mget(xpath("//meta[@name='dc.date']"))
      desc =      page |> mget(xpath("//meta[@name='dc.description']")) |> String.replace(~r/(\r|\n)\s+\+/, "")
      abstract =  (
        page |> Meeseeks.one(xpath("//div[@id='abstract-content']"))
        || page |> Meeseeks.one(xpath("//div[@id='Abs1-content']"))
        || page |> Meeseeks.one(xpath("//div[@itemprop='description']"))
      ) |> Meeseeks.html

      Repo.get_by(Nature.Paper, id: paper.id)
      |> Ecto.Changeset.change(
        title: title,
        auths: auths,
        from: from,
        doi: doi,
        labels: labels,
        date: date,
        desc: desc,
        abstract: abstract,
      )
      |> Repo.update!
      Logger.info "Paper done: #{paper.link}"
    rescue
      FunctionClauseError ->
        Logger.warn "Paper Page imcomplete: #{paper.link}, ##{cnt}"
        _goto(paper, cnt + 1)
      RuntimeError ->
        Logger.warn "Paper Page imcomplete: #{paper.link}, ##{cnt}"
        _goto(paper, cnt + 1)
    end
  end

  defp _filter(subs) do
    Repo.all(
      from p in Nature.Paper,
      where: (
        p.labels == type(^[], {:array, :string}) and
        p.subject in ^subs and
        is_nil p.doi
      ),
      limit: @limit
    )
  end

  def bio do
    Repo.all(
      from s in Nature.Subject,
      where: "Biological sciences" in s.parent,
      select: s.name
    )
  end

  def med do
    Repo.all(
      from s in Nature.Subject,
      where: "Health sciences" in s.parent,
      select: s.name
    )
  end

  def che, do: ["Chemistry"]
  def bmc, do: bio() ++ med() ++ che() |> Enum.uniq
  def bm, do: bio() ++ med() |> Enum.uniq

  def main(subs \\ nil) do
    subs = case subs do
      nil -> bmc()
      [] -> bmc()
      s -> s
    end
    papers = _filter(subs)

    case papers do
      [] ->
        Logger.info "Paper under #{subs} all done."
      _ ->
        cnt = div(length(papers) - 1, nthreads()) + 1
        papers
        |> (fn [h|t] ->
          _goto(h)
          t
        end).()
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
