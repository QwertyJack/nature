defmodule Nature.Subject do
  use Ecto.Schema

  schema "subject" do
    field(:name, :string)
    field(:parent, :string)
    field(:link, :string)
    field(:progress, :integer)

    timestamps()
  end
end

