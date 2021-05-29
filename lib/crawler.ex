defmodule Crawler do
  def run(seed_url) do
    Agent.start_link fn -> [] end, name: :crawled_result

    crawl(seed_url, seed_url)

    result = Agent.get :crawled_result, &(&1)
    Agent.stop :crawled_result
    result
  end

  defp crawl(target_url, seed_url) do
    crawled_link_list = Agent.get :crawled_result, fn list -> Enum.map(list, &(&1[:url])) end

    if !Enum.member?(crawled_link_list, target_url) do
      IO.puts "access: #{target_url}"

      %HTTPoison.Response{status_code: status_code, body: body} = HTTPoison.get!(target_url)

      document = Floki.parse_document! body
      page_info = document
                  |> parse_title_and_description
                  |> Map.merge(%{url: target_url, status_code: status_code})
      un_crawled_link_list = document
                             |> parse_same_host_links(URI.parse(seed_url).host)
                             |> Enum.filter(&!Enum.member?(crawled_link_list, &1))

      Agent.update(:crawled_result, &([page_info | &1]))
      Enum.map(un_crawled_link_list, &(crawl(&1, seed_url)))
    end
  end

  defp parse_same_host_links(document, host) do
    document
    |> Floki.find("a")
    |> Floki.attribute("href")
    |> Enum.filter(& &1)
    |> Enum.map(&URI.parse &1)
    |> Enum.filter(& &1.host == host)
    |> Enum.map(&to_absolute_uri &1, host)
    |> Enum.filter(&Regex.match?(~r/^(http|https)/, &1.scheme))
    |> Enum.map(&URI.to_string &1)
  end

  defp to_absolute_uri(uri, host) do
    case uri.host do
      nil -> URI.merge(host, uri)
      _ -> uri
    end
  end

  defp parse_title_and_description(document) do
    title = document
            |> Floki.find("title")
            |> Floki.text
    description = document
                  |> Floki.find("meta[name=description]")
                  |> Floki.attribute("content")
                  |> Enum.at(0)
    %{title: title, description: description}
  end
end
