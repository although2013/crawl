require 'active_record'
require 'postgresql'
require 'nokogiri'

# Set up a database that resides in RAM
ActiveRecord::Base.establish_connection(
  host: 'localhost',
  adapter: 'postgresql',
  database: 'gehao',
  user: 'postgres'
)


class Crawl < ActiveRecord::Base
  self.table_name = "suumo"
  self.primary_key = 'id'


  def to_json
    page = Nokogiri::HTML(body)
    props = {}
    page.css('.property_data-title, .property_data-body')
        .each_slice(2)
        .each { |a| props[a.first.text.strip] = a.last.text.gsub(/\s+/, "") }
    {
      id: id,
      url: url.delete_prefix("https://suumo.jp/"),
      title: page.css('title').text,
      price: page.css('.property_view_main-emphasis').text.strip,
      properties: props
    }
  end

end

p Crawl.last.to_json
