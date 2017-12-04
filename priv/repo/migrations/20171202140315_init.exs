defmodule Nature.Repo.Migrations.Init do
  use Ecto.Migration

  def change do
    create table(:subject) do
      add(:name, :string, unique: true)
      add(:parent, {:array, :string}, default: [])
      add(:ancestors, {:array, :string}, default: [])
      add(:link, :string)
      add(:description, :text)
      add(:progress, :integer, default: -1)

      timestamps()
    end

    create table(:paper) do
      add(:link, :string, unique: true)
      add(:subject, :string)
      add(:title, :text)
      add(:auths, {:array, :string})
      add(:from, :string)
      add(:doi, :string)
      add(:labels, {:array, :string}, default: [])
      add(:date, :string)
      add(:abstract, :text)

      timestamps()
    end
  end
end
