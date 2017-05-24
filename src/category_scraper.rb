require 'open-uri'
require 'open_uri_redirections'
require 'nokogiri'
require 'csv'

#take command line args
category_url = ARGV[0]
file_name = ARGV[1]
# category_url = 'https://www.petsonic.com/snacks-huesos-para-perros/'
# file_name = 'output.csv'
write_mode = 'a'
pagination_postfix = '?p='

# clear file if exists
CSV.open(file_name, 'w')

# define final url value if redirected
final_url = ''
open(category_url, :allow_redirections => :all) do |resp|
  final_url = resp.base_uri.to_s
end

# build category page
category_html = open(final_url)
category_doc = Nokogiri::HTML(category_html)
page_number = category_doc.css('ul.pagination.pull-left>li:not([class="pagination_next"]) a span').last.content.to_i

# collect category pagination page urls
page_urls = []
(1..page_number).each { |i|
  page_urls.push(final_url + pagination_postfix + i.to_s)
}

# process script for each page
page_urls.each_with_index do |page, index|

  # build current page
  current_page_html = open(page)
  current_page_doc = Nokogiri::HTML(current_page_html)

  # collect product page urls on current page
  product_urls = []
  url_node_set = current_page_doc.css('a.product_img_link')
  url_node_set.each do |node|
    product_urls.push(node['href'])
  end

  # process script for each product on page
  product_urls.each do |product|

    # build product page
    product_page_html = open(product)
    product_page_doc = Nokogiri::HTML(product_page_html)

    # collect product data on product page
    objects = []
    headers = []
    prices = []
    picture = product_page_doc.css('#bigpic')[0]['src']
    header = product_page_doc.search('h1').xpath('text()').text.strip

    # collect product prices data
    product_page_doc.css('span.attribute_price').each do |item|
      prices.push(item.content.scan(/\d+\.\d{,2}/).first)
    end

    # collect and build product headers data
    name_nodes = product_page_doc.css('span.attribute_name')
    if name_nodes.length > 0
      product_page_doc.css('span.attribute_name').each do |item|
        headers.push("#{header} #{item.content}")
      end
    else
      (0..prices.length).each {
        headers.push(header)
      }
    end


    # build object rows array
    (0..headers.length-1).each { |i|
      objects.push([headers[i], prices[i], picture])
    }

    # write to csv
    CSV.open(file_name, write_mode) do |csv|
      objects.each do |obj|
        csv << obj
      end
    end

  end

  # uncomment to write comment about page ending to csv
  # CSV.open(file_name, write_mode) do |csv|
  #   csv << ["# ----- end of #{index+1} page -----"]
  # end

end