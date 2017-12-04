defmodule Nature.Repo.Migrations.LabelDefault do
  use Ecto.Migration

  def change do
    alter table(:paper) do
      remove(:labels)
      add(:labels, {:array, :string}, default: [])
    end
  end
end
