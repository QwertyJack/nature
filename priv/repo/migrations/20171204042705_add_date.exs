defmodule Nature.Repo.Migrations.AddDate do
  use Ecto.Migration

  def change do
    alter table(:paper) do
      add(:date, :string)
    end
  end
end
