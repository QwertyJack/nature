defmodule Nature.Repo.Migrations.AlterAuths do
  use Ecto.Migration

  def change do
    alter table(:paper) do
      remove(:auths)
      add(:auths, {:array, :string})
    end
  end
end
