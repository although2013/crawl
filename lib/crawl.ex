require IEx

defmodule Crawl do
  def detail_page(url) do
    IO.puts(url)
    {:ok, response} = HTTPoison.get(url, [], [follow_redirect: true])

    [[_, views, upvote, downvote]] = Regex.scan(~r/nb-views-number">(.+?)<\/str.+?rating.+?>(.+?)<\/span>.+?rating.+?>(.+?)<\/span>/, response.body)
    tags = Regex.scan(~r/\/tags\/(.+?)"/, response.body) |>
            Enum.map(fn ele -> Enum.at(ele, 1) end)
    time = case Regex.scan(~r/"duration">(.+?)<\/span>/, response.body) do
      [[_, time]] -> time
      _ -> ""
    end
    resolution = case Regex.scan(~r/video-hd-mark">(.+?)</, response.body) do
      [[_, res]] -> res
      _ -> ""
    end

    %{ views: views, upvote: upvote, downvote: downvote, tags: tags, time: time, resolution: resolution }
  end

  def main(listen_pid) do
    base_url = "https://www.xvideos.com"
    HTTPoison.start
    {:ok, response} = HTTPoison.get(base_url)
    matches = Regex.scan(~r/data-id="(.+?)".+?<p class="title"><a href="(.+?)".+?title="(.+?)"/, response.body)
    Enum.each(Enum.with_index(matches), fn ele ->
      {[_, id, href, title], idx} = ele
      # if idx < 5 do
        # Task.async(fn ->
          msg = detail_page(base_url<>href) |>
                    Map.merge(%{id: id, href: href, title: title})
          send(listen_pid, msg)
        # end) |> Task.await
      # end
    end)
  end

  def save(msg) do
    tags = "{\"" <> Enum.join(msg[:tags], "\",\"") <> "\"}"
    "INSERT INTO crawl (site_id,title,href,views,upvote,downvote,tags,time,resolution) VALUES ('#{msg[:id]}','#{msg[:title]}','#{msg[:href]}','#{msg[:views]}','#{msg[:upvote]}','#{msg[:downvote]}','#{tags}','#{msg[:time]}','#{msg[:resolution]}')"
  end

  def listen(sql_pid) do
    receive do
      msg ->
        IO.puts(inspect(msg))
        Postgrex.query!(sql_pid, save(msg), [])
    end
    listen(sql_pid)
  end

  def establish do
    {:ok, pid} = Postgrex.start_link(hostname: "localhost", username: "postgres", password: "", database: "gehao")
    pid
  end
end


# sql_pid = Crawl.establish
# listen = spawn(Crawl, :listen, [sql_pid])
# Crawl.main(listen)
