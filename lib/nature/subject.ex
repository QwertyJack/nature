defmodule Nature.Subject do
  use Ecto.Schema

  schema "subject" do
    field(:name, :string)
    field(:parent, {:array, :string})
    field(:ancestors, {:array, :string})
    field(:link, :string)
    field(:description, :string)
    field(:progress, :integer)

    timestamps()
  end

  @limit 30
  require Logger
  import Ecto.Query
  import Meeseeks.XPath

  alias Nature.Repo
  import Nature.Util

  defp _url, do: "https://www.nature.com/subjects"
  defp _get_level(subject) do
    Repo.one(
      from s in Nature.Subject,
      where: (s.name == ^subject),
      select: s.ancestors
    )
    |> length
  end

  defp _get_subject_id(subject) do
    Repo.one(
      from s in Nature.Subject,
      where: (s.name == ^subject),
      select: s.link
    )
    |> _link2id
  end

  defp _link2id(link) do
    link
    |> (&Regex.named_captures(~r/subjects\/(?<id>.*?)$/, &1)).()
    |> Map.get("id")
  end

  defp _progress(subject, npage \\ 0) do
    Repo.get_by(Nature.Subject, name: subject)
    |> Ecto.Changeset.change(progress: npage)
    |> Repo.update!
  end

  @doc "Build subject tree root."
  def init do
    _url()
    |> get
    |> Meeseeks.all(xpath("//a[@class='pill-button inline-block']"))
    |> Enum.each(
      &(&1
      |> Meeseeks.attr("href")
      |> (fn path ->
        link = domain() <> path
        case Repo.get_by(Nature.Subject, link: link) do
          nil -> %Nature.Subject{link: link, parent: [], ancestors: []}
          |> Repo.insert!
          _ -> :ok
        end
      end).()
      )
    )

    fill()
  end

  @doc "Fill subject tree"
  def fill do
    Repo.all(
      from sub in Nature.Subject,
      where: (
        is_nil(sub.description) and
        sub.progress >= -1
      ),
      limit: @limit
    )
    |> case do
      [] -> :ok
      subs -> #Enum.each(&(&1 |> explorer))
        cnt = div(length(subs) - 1, nthreads()) + 1
        subs
        |> Enum.chunk(cnt, cnt, [])
        |> Enum.map(&Task.async(fn ->
          &1
          |> Enum.each(fn item ->
            explorer(item)
          end)
        end))
        |> Enum.map(&Task.await(&1, :infinity))

        fill()
    end
  end

  def check do
    Repo.all(
      from sub in Nature.Subject,
      where: sub.progress < -1
    )
    |> case do
      [] -> :ok
      subs -> Enum.each(subs, &(&1 |> explorer))
    end
    fill()
  end

  def explorer(sub) do
    Logger.info "Subject #{sub.link}"
    page = sub.link |> get
    case page do
      :http_fail ->
        Repo.get_by(Nature.Subject, id: sub.id)
        |> Ecto.Changeset.change(
          progress: -100,
          description: "",
        )
        |> Repo.update!
      _ -> analyze(sub, page)
    end
  end

  def analyze(sub, page) do
    description = page |> mget(xpath("//meta[@name='description']")) |> String.replace(~r/(\r|\n)\s+\+/, "")

    name = case sub.parent do
      [] -> name = page |> mget(xpath("//meta[@name='WT.z_cg_cat']"))
        Repo.get_by(Nature.Subject, id: sub.id)
        |> Ecto.Changeset.change(
          name: name,
          description: description,
          progress: -1,
        )
        |> Repo.update!
        name
      _ ->
        Repo.get_by(Nature.Subject, id: sub.id)
        |> Ecto.Changeset.change(
          description: description,
          progress: -1,
        )
        |> Repo.update!
        sub.name
    end

    # find children subject
    page
    |> Meeseeks.all(xpath("//li[@class='pb4']/a[@class='subject-tag-link text14']"))
    |> Enum.each(fn a ->
      path = a |> Meeseeks.attr("href")
      cname = a |> Meeseeks.text
      link = domain() <> path
      case Repo.get_by(Nature.Subject, link: link) do
        nil -> %Nature.Subject{
          name: cname,
          link: link,
          parent: [name],
          ancestors: sub.ancestors ++ [name]
        }
        |> Repo.insert!
        s ->
          if not name in s.parent do
            s
            |> Ecto.Changeset.change(parent: s.parent ++ [name])
            |> Repo.update!
          else
            Logger.error "Wrong path: #{name}, #{s.name}, #{s.parent}"
          end
          Logger.info "Subject update #{s.name} with new parent: #{name}, old: #{s.parent}"
      end
    end)
  end

  defp _goto(subject, npage \\ 1) do
    Logger.info "Subject #{subject} search at page #{npage}"
    page = "#{domain()}/search?article_type=protocols%2Cresearch%2Creviews&subject=#{subject |> URI.encode}&page=#{npage}"
           |> get

    is_end = page
             |> Meeseeks.one(xpath("//li[@data-page='next']"))
             |> case do
               nil -> Logger.warn "Subject #{subject} has no other pages"
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
        Logger.info "Subject find #{title} at #{link}"
        _ -> nil
      end
    end)

    Logger.info "Subject done #{subject} at page #{npage}"
    npage = npage + 1
    _progress(subject, npage)

    if is_end do
      _progress(subject)
      Logger.info "Subject #{subject} all done."
    else
      _goto(subject, npage)
    end
  end

  @doc "Search papers of all subject"
  def search() do
    subs = Repo.all(
      from sub in Nature.Subject,
      where: (
        fragment("array_length(?, 1)", sub.ancestors) == 1 and
        sub.progress != 0
      )
    )

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
