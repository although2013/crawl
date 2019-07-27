require IEx

defmodule Crawl.Extract do
  def test do
    {:ok, body} = File.read("lib/crawl/sample.html")
    to_json(body)
  end

  def bc_ids(body) do
    Regex.scan(~r/\bbc(=|_)(\d+)\b/, body) |> Enum.map(&Enum.at(&1, 2)) |> Enum.uniq
  end

  def to_json(body) do
    house = try do
      basic_price(body)
              |> Map.merge(basic_address(body))
              |> Map.merge(detail_props(body))

    rescue
      _ -> IEx.pry
    end

    house
  end

  def basic_address(body) do
    Floki.find(body, ".property_view_detail-header-title, .property_view_detail-text")
        |> Enum.slice(2..-1)
        |> Enum.map(fn ele ->
              Floki.text(ele) |> String.trim
            end)
        |> Enum.split_while(fn x -> x != "所在地" end)
        |> Tuple.to_list()
        |> Enum.map(fn [k| v] ->
              [k, Enum.join(v, "\n")]
            end)
        |> Map.new(fn [k, v] -> {k, v} end)
  end

  def basic_price(body) do
    house = Floki.find(body, ".property_data-title, .property_data-body")
            |> Enum.map(fn ele ->
              Floki.text(ele) |> String.replace(~r/\s/, "")
            end)
            |> Enum.chunk_every(2)
            |> Map.new(fn [k, v] -> {k, v} end)

    price = Floki.find(body, ".property_view_main-emphasis")
            |> Floki.text
            |> String.trim
    house = Map.put(house, "price", price)

    title = Floki.find(body, ".desc-title")
            |> Floki.text
            |> String.trim
    Map.put(house, "title", title)
  end

  def detail_props(body) do
    house = Floki.find(body, ".table_gaiyou tr")
          |> Floki.find("th, td")
          |> Floki.filter_out(".blank_td")
          |> Enum.map(fn ele ->
               Floki.text(ele, sep: "\n") |> String.trim
             end)
          |> Enum.chunk_every(2)
          |> Map.new(fn [k, v] -> {String.replace(k, ~r/\s/, ""), v} end)
          |> Map.delete("携帯用QRコード")

    equip = Floki.find(body, ".bgc-wht ul li") |> Floki.text
    house = Map.put(house, "部屋の特徴・設備", equip)

    date = Floki.find(body, ".pagetop.mgnt-5") |> Floki.text
    date = case Regex.scan(~r/\d+\/\d+\/?\d{0,2}/, date) do
      [[date]] -> date
      _ -> ""
    end
    Map.put(house, "update_time", date)
  end
end
