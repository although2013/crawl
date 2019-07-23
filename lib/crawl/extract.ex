require IEx

defmodule Crawl.Extract do
  def start_link() do
    
  end

  def run do
    {:ok, body} = File.read("lib/crawl/sample.html")
    house = basic_price(body)
              |> Map.merge(basic_address(body))
              |> Map.merge(detail_props(body))

    house
  end

  def basic_address(body) do
    Floki.find(body, ".property_view_detail-header-title, .property_view_detail-text")
            |> Enum.slice(2..-1)
            |> Enum.map(fn ele ->
               Floki.text(ele) |> String.trim
             end)
            |> Enum.chunk_every(2)
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
    Map.put(house, "price", price)
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
    Map.put(house, "部屋の特徴・設備", equip)
  end

end
