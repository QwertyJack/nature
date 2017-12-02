defmodule Crawler do
  require Logger
  import Meeseeks.XPath
  alias Nature.Repo

  def url, do: "https://www.nature.com/subjects"
  def domain, do: "https://www.nature.com"
  def nproc, do: 6

  @doc "HTTP GET wrapper"
  def wget(u, follow \\ false, cnt \\ 0) do
    try do
      HTTPoison.get!(u, [], [follow_redirect: follow])
    rescue
      HTTPoison.Error ->
        cnt = cnt + 1
        Logger.debug "HTTP fail for #{cnt} times, retry ..."
        wget(u, follow, cnt)
    end
  end

  @doc "Visit nature.com, 1st 303, then follow 302 until the end"
  def visit(u) do
    ret = wget(u).headers
    |> Enum.filter(fn({k, _}) -> k == "Location" end)
    |> hd
    |> elem(1)
    |> wget(true)

    ret.body
  end

  def init do
    url()
    |> visit
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

  def go(subject, npage \\ 1) do
    Logger.info "Crawling #{subject} at page #{npage}"
    page = "#{domain()}/search?article_type=protocols%2Cresearch%2Creviews&subject=#{subject |> URI.encode}&page=#{npage}"
    |> visit

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

    npage = npage + 1
    Repo.get_by(Nature.Subject, name: subject)
    |> Ecto.Changeset.change(progress: npage)
    |> Repo.update!
    Logger.info "Done #{subject} at page #{npage}"

    if is_end do
      Repo.get_by(Nature.Subject, name: subject)
      |> Ecto.Changeset.change(progress: 0)
      |> Repo.update!
      Logger.info "Subject #{subject} all done."
    else
      go(subject, npage)
    end
  end

  def main() do
    subs = Nature.Subject
           |> Repo.all
           |> Enum.filter(&(&1.progress != 0))
           |> Enum.sort

    cnt = div(length(subs) - 1, nproc()) + 1
    subs
    |> Enum.chunk(cnt, cnt, [])
    |> Enum.map(&Task.async(fn ->
      &1
      |> Enum.each(fn item ->
        go(item.name, item.progress |> Kernel.abs)
      end)
    end))
    |> Enum.map(&Task.await(&1, :infinity))
  end
end
