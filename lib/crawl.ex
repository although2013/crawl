require IEx

defmodule Crawl do
  def start_link(url) do
    HTTPoison.start
    Crawl.Data.start_link

    first_url = url
    # if exist?(first_url) do
    #   IO.puts("cccccccccccc")
    #   %{rows: [[_, first_url]]} = Crawl.Data.last
    # end

    Task.start_link(fn -> process(first_url) end)
  end

  def get_page(reason, 0) do
    {:error, reason}
  end

  def get_page(url, retry) do
    IO.puts("retry #{retry}, #{Time.utc_now} #{url}")
    case HTTPoison.get(url) do
      {:ok, response} -> {:ok, response}
      {:error, _} ->
        wait = :math.pow(2, (8-2*retry))
        :timer.sleep(round(1000*wait))
        get_page(url, (retry-1))
    end
  end

  def process(url) do
    unless exist?(url) do
      # TODO get_page return could not match
      {:ok, response} = get_page(url, 3)
      body = extract(response.body)
      save(url, body)

      links = response.body
        |> Floki.find("body a")
        |> Floki.attribute("href")
        |> Enum.filter(fn link ->
                  Regex.match?(~r/(\?bc_\d+\/|\/jj\/|jnc_\d+\/)/, link) &&
                  Regex.match?(~r/\/chintai\//, link)
                end)
        |> Enum.map(fn link ->
            URI.merge("https://suumo.jp", link)
                |> URI.to_string
                |> String.trim
        end)
        |> Enum.uniq()
        |> Enum.filter(fn link ->
                  String.starts_with?(link, "https") &&
                  !Regex.match?(~r/(void\(0\)|\/showLogin\/|\/kankyo\/|\/tenpo\/|\.css\/|favicon.ico)/, link)
                end)

      Enum.each(links, fn link ->
        process(link)
      end)

      # stream = Task.async_stream(
      #                 links,
      #                 Crawl,
      #                 :process,
      #                 [pid],
      #                 max_concurrency: 1,
      #                 ordered: false)
      # Stream.run(stream)
    end
  end

  def extract(str) do
    
    str |> Floki.find(".property_view_note-list span")
        |> Enum.each(fn item -> IO.puts(Floki.text(item)) end)

      # page.css()
      #   .each_slice(2)
      #   .each { |a| props[a.first.text.strip] = a.last.text.gsub(/\s+/, "") }
    # {
    #   id: id,
    #   url: url.delete_prefix("https://suumo.jp/"),
    #   title: page.css('title').text,
    #   price: page.css('.property_view_main-emphasis').text.strip,
    #   properties: props
    # }
  end

  def save(url, body) do
    Crawl.Data.create(%{url: url, body: body})
  end

  def exist?(url) do
    Crawl.Data.exist?(url)
  end

end

# Crawl.establish
# listen_pid = spawn(Crawl, :listen, [sql_pid])
# Crawl.main(listen_pid)
