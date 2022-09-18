# Youtube Scraper

Technically it scrapes [Invidious](https://invidious.io/) instances, not actual Youtube. Stores known video URLs in a local SQLite database and only shows new videos.

It provides each individual video URL in a line w/ the title commented out so you can just paste it, and also a download command for all new videos. The download command used is `dl` - assumed to be an alias for e.g. [yt-dlp](https://github.com/yt-dlp/yt-dlp/) or similar.

## Setup

Comment in the Ecto lines for creating and migrating the database on first run, then comment them back out or they might overwrite the existing database.

It is recommended you symlink the executable `youtube_scraper.exs` script to `/usr/local/bin` or somewhere else in your path.

## Configuring channels to scrape

Copy the `channels.exs.example` file to `channels.exs` and add your channels to it.

This takes the form of tuples containing the name you want displayed, and the Youtube URL fragment (not including the domain):
```
{"Saturday Night Live", "channel/UCqFzWxSCi39LnW1JKFR3efg"}
```
