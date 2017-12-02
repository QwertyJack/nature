defmodule Nature.Repo.Migrations.Init do
  use Ecto.Migration

  def change do
    create table(:subject) do
      add(:name, :string, unique: true)
      add(:parent, :string)
      add(:link, :string)
      add(:progress, :integer, default: -1)

      timestamps()
    end

    create table(:paper) do
      add(:link, :string, unique: true)
      add(:subject, :string)
      add(:title, :text)
      add(:auths, :text)
      add(:from, :string)
      add(:doi, :string)
      add(:labels, {:array, :string})
      add(:abstract, :text)

      timestamps()
    end
  end
end
