defmodule Nature.Subject do
  use Ecto.Schema

  schema "subject" do
    field(:name, :string)
    field(:parent, :string)
    field(:link, :string)
    field(:progress, :integer)

    timestamps()
  end

  require Logger
  import Ecto.Query
  import Meeseeks.XPath

  alias Nature.Repo
  import Nature.Util

  defp _progress(subject, npage \\ 0) do
    Repo.get_by(Nature.Subject, name: subject)
    |> Ecto.Changeset.change(progress: npage)
    |> Repo.update!
  end

  def init do
    url()
    |> get
    |> Meeseeks.all(xpath("//div[@class='container cleared container-type-link-grid']"))
    |> Enum.each(&(&1
      |> Meeseeks.html
      |> (fn html ->
        parent = Meeseeks.one(html, xpath("//h2")) |> Meeseeks.text
        html
        |> Meeseeks.all(xpath("//li[@class='pb4']"))
        |> Enum.each(fn item ->
          name = item |> Meeseeks.text
          link = item |> Meeseeks.one(xpath("//a")) |> Meeseeks.attr("href")
          case Repo.get_by(Nature.Subject, name: name) do
            nil -> %Nature.Subject{
              name: name,
              parent: parent,
              link: domain() <> link
            } |> Repo.insert!
            Logger.info "Add #{name}"
            _ -> nil
          end
        end)
      end).()
    ))
  end

  defp _goto(subject, npage \\ 1) do
    Logger.info "Crawling #{subject} at page #{npage}"
    page = "#{domain()}/search?article_type=protocols%2Cresearch%2Creviews&subject=#{subject |> URI.encode}&page=#{npage}"
           |> get

    is_end = page
             |> Meeseeks.one(xpath("//li[@data-page='next']"))
             |> case do
               nil -> Logger.warn "#{subject} has no other pages"
                 true
               x -> x
               |> Meeseeks.attr("class")
               |> (&Regex.match?(~r/disabled/, &1)).()
             end

    page
    |> Meeseeks.all(xpath("//li[@class='mb20 pb20 cleared']//a[@itemprop='url']"))
    |> Enum.each(fn item ->
      title = item |> Meeseeks.text
      link = item |> Meeseeks.attr("href")
      case Repo.get_by(Nature.Paper, link: link) do
        nil -> %Nature.Paper{
          link: link,
          subject: subject,
        } |> Repo.insert!
        Logger.info "Find #{title} at #{link}"
        _ -> nil
      end
    end)

    Logger.info "Done #{subject} at page #{npage}"
    npage = npage + 1
    _progress(subject, npage)

    if is_end do
      _progress(subject)
      Logger.info "Subject #{subject} all done."
    else
      _goto(subject, npage)
    end
  end

  def main() do
    subs = Repo.all(from sub in Nature.Subject, where: sub.progress != 0)

    cnt = div(length(subs) - 1, nthreads()) + 1
    subs
    |> Enum.chunk(cnt, cnt, [])
    |> Enum.map(&Task.async(fn ->
      &1
      |> Enum.each(fn item ->
        _goto(item.name, item.progress |> Kernel.abs)
      end)
    end))
    |> Enum.map(&Task.await(&1, :infinity))
  end

end
