defmodule Nature.Repo.Migrations.RenewAb do
  use Ecto.Migration

  def change do
    alter table(:paper) do
      add(:desc, :text)
    end
  end
end
