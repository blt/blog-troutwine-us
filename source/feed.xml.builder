xml.instruct!
xml.feed "xmlns" => "http://www.w3.org/2005/Atom" do
  xml.title "Brian L. Troutwine: A Fairly Okay Fellow"
  xml.id "http://blog.troutwine.us/"
  xml.link "href" => "http://blog.troutwine.us/"
  xml.link "href" => "http://blog.troutwine.us/feed.xml", "rel" => "self"
  xml.updated data.blog.articles.first.date.to_time.iso8601
  xml.author { xml.name "Brian L. Troutwine" }
  xml.icon "http://blog.troutwine.us/images/favicon.png"

  data.blog.articles.each do |article|
    xml.entry do
      xml.title article.title
      xml.link "rel" => "alternate", "href" => article.url
      xml.id article.url
      xml.published article.date.to_time.iso8601
      xml.updated article.date.to_time.iso8601
      xml.author { xml.name "Brian L. Troutwine" }
      xml.summary article.summary, "type" => "html"
      xml.content article.body, "type" => "html"
    end
  end
end