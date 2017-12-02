defmodule Nature.Paper do
  use Ecto.Schema
  import Ecto.Changeset

  schema "paper" do
    field(:link, :string)
    field(:subject, :string)
    field(:title, :string)
    field(:auths, :string)
    field(:from, :string)
    field(:doi, :string)
    field(:labels, {:array, :string})
    field(:abstract, :string)

    timestamps()
  end
end

