Application.put_env(
  :youtube_scraper,
  Repo,
  database: PathHelper.relative_file("youtube_scraper.db"),
  log: false
)

defmodule Repo do
  use Ecto.Repo,
    otp_app: :youtube_scraper,
    adapter: Ecto.Adapters.SQLite3
end

defmodule CreateVideosMigration do
  use Ecto.Migration

  def change do
    create table(:videos) do
      add(:url, :string)

      timestamps()
    end
  end
end

defmodule Video do
  use Ecto.Schema

  schema "videos" do
    field(:url)

    timestamps()
  end
end
