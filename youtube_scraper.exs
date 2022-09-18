#!/usr/bin/env elixir

Mix.install([
	{:httpoison, "~> 1.8"},
	{:floki, "~> 0.32.0"},
	{:ecto_sqlite3, "~> 0.7.5"},
	{:ecto, "~> 3.8"}
])

defmodule PathHelper do
  def relative_file(filename) do
    Path.join(cwd(), filename)
  end

	defp follow_symlink(path) do
		{raw_path, 0} = System.cmd("readlink", [path])

		String.trim(raw_path)
	end

	defp cwd do
		raw_path = __ENV__.file
		path = case File.lstat!(raw_path).type do
			:symlink -> follow_symlink(raw_path)
			:regular -> raw_path
		end

		Path.dirname(path)
	end
end

Code.eval_file(PathHelper.relative_file("channels.exs"))
Code.eval_file(PathHelper.relative_file("ecto.exs"))

defmodule YoutubeScraper do
	import Ecto.Query

	@timeout 10000
	# Instance list: https://docs.invidious.io/instances/
	# @instance "vid.puffyan.us"
	@instance "invidious.namazso.eu"

	def start do
		# :ok = Repo.__adapter__().storage_up(Repo.config())

		{:ok, _} = Supervisor.start_link([Repo], strategy: :one_for_one)

		# Ecto.Migrator.run(Repo, [{0, CreateVideosMigration}], :up, all: true, log_sql: :debug)

		new_content =
			Channels.all()
			|> Enum.map(&dispatch/1)
			|> Enum.map(fn task -> Task.await(task, @timeout) end)
			|> Enum.filter(& Enum.count(&1.videos) > 0)

		Enum.each(new_content, fn channel ->
			print_description(channel)
			save_to_database(channel)
		end)

		if Enum.count(new_content) > 0 do
			print_dl_link(new_content)
		end
	end

	defp dispatch({channel_name, url}) do
		Task.async(fn ->
			videos = grab_channel(url)
			filtered_videos = videos |> Enum.filter(fn {_name, url} ->
				in_db = Video
					|> where(url: ^url)
					|> Repo.all
					|> Enum.count

				in_db == 0
			end)
			%{name: channel_name, videos: filtered_videos}
		end)
	end

	defp grab_channel(url) do
		"https://#{@instance}/#{url}/videos"
		|> fetch
		|> parse
	end

	defp fetch(url) do
		case HTTPoison.get(url, [], hackney: [follow_redirect: true]) do
			{:ok, response} -> response.body
			{:error, error} -> IO.puts(:stderr, "Error fetching #{url}: #{error.reason}")
		end
	end

	defp parse(html) do
		css_path = "#contents .pure-u-1.pure-u-md-1-4 .h-box"
		{:ok, document} = Floki.parse_document(html)

		Floki.find(document, css_path)
		|> Enum.map(&link_from_el/1)
	end

	defp link_from_el({_tag, _attrs, content}) do
		{_, attrs, content} = Floki.find(content, "a") |> List.first()
		{_, chunk_url} = Enum.find(attrs, fn {type, _} -> type == "href" end)
		[_, {_, _, [name]}] = content
		{name, chunk_url}
	end

	defp full_url(chunk_url) do
		"https://" <> @instance <> chunk_url
	end

	defp print_description(%{name: channel_name, videos: videos}) do
		video_strings = Enum.map(videos, fn {title, url} ->
			[:white, full_url(url), :cyan, " # ", title, "\n"]
			|> IO.ANSI.format
		end)
		underline = channel_name |> String.replace(~r/./, "-")

		[channel_name, underline, video_strings]
		|> Enum.each(&IO.puts/1)
	end

	defp print_dl_link(channels) do
		IO.write "dl "

		Enum.map(channels, fn channel ->
			Enum.map(channel.videos, fn {_, url} -> full_url(url) end)
		end)
		|> List.flatten
		|> Enum.join(" ")
		|> IO.puts
	end

	defp strip_url(url) do
		String.replace_leading(url, "https://" <> @instance, "")
	end

	defp save_to_database(%{videos: videos}) do
		Enum.each(videos, fn {_name, url} -> Repo.insert(%Video{url: strip_url(url)}) end)
	end
end

YoutubeScraper.start
