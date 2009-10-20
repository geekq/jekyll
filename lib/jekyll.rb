$:.unshift File.dirname(__FILE__)     # For use/testing when no gem is installed

# rubygems
require 'rubygems'

# core
require 'fileutils'
require 'time'
require 'yaml'

# stdlib
require 'open-uri'

# 3rd party
require 'liquid'
require 'redcloth'
require 'hpricot'
begin
  require 'maruku'
rescue LoadError
  puts "The maruku gem is required for markdown support!"
end

# internal requires
require 'jekyll/core_ext'
require 'jekyll/site'
require 'jekyll/convertible'
require 'jekyll/layout'
require 'jekyll/page'
require 'jekyll/post'
require 'jekyll/filters'
require 'jekyll/tags/highlight'
require 'jekyll/tags/include'
require 'jekyll/tags/markdown'
require 'jekyll/tags/smartypants'
require 'jekyll/albino'

module Jekyll
  class << self
    attr_accessor :source, :dest, :site, :lsi, :pygments, :markdown_proc, :content_type, :permalink_style
  end
  
  Jekyll.lsi = false
  Jekyll.pygments = false
  Jekyll.markdown_proc = Proc.new { |x| Maruku.new(x).to_html }
  Jekyll.permalink_style = :pretty
  
  def self.process(source, dest)
    require 'classifier' if Jekyll.lsi
    
    ext_file = File.join(source, '_jekyll/extensions.rb')
    if File.exists?(ext_file)
      require ext_file
    end

    Jekyll.source = source
    Jekyll.dest = dest
    # Read regular expressions identifying files to ignore from
    # .jekyllignore.
    ignore_pattern = FileTest.exist?(File.join(source, '.jekyllignore')) ? File.open(File.join(source, '.jekyllignore')) { |f| f.read.split.join('|') } : '^$'
    Jekyll.site = Jekyll::Site.new(source, dest, ignore_pattern)
    Jekyll.site.process
  end
  
  def self.version
    yml = YAML.load(File.read(File.join(File.dirname(__FILE__), *%w[.. VERSION.yml])))
    "#{yml[:major]}.#{yml[:minor]}.#{yml[:patch]}"
  end

  BINARY = File.expand_path(File.dirname(__FILE__) + '/../bin/jekyll')
end
