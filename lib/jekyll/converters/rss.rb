module Jekyll

  require 'rexml/document'
  require 'time'
  require "YAML"

  module RSS
    #Reads posts from an RSS feed.
    #It creates a post file for each entry in the RSS.
    def self.process(source = "rss.xml")
      #FileUtils.mkdir_p "_posts"
      content = ""
      open(source, "r") { |f| content << f.read }
      doc = REXML::Document.new(content)
      posts = 0
      doc.elements.each("rss/channel/item") do |item|
        link = item.elements["link"].text
        name = link.split("/")[-1]
        name = $1 if name =~ /(.*)\.html/
        name = $1 if name =~ /\d+\-(.*)/

        #title = item.elements["title"].text
        content = item.elements["content:encoded"].text
        timestamp = Time.parse(item.elements["pubDate"].text)
        filename = "_posts/#{timestamp.strftime("%Y-%m-%d")}-#{name}.html"
        puts "#{link} -> #{filename}"
        File.open(filename, "w") do |f|
          YAML.dump(
            {
              "layout" => "post",
              "name" => name,
              "title" => item.elements["title"].text,
              "time" => timestamp,
            },
            f
          )
          f.puts "---\n#{content}"
        end
        posts += 1
      end
      puts "Created #{posts} posts!"
    end
  end
end
