defmodule Crawler.CLI do
  def main(args) do
    [url | tail] = args
    url
    |> Crawler.run
    |> IO.inspect
  end
end
