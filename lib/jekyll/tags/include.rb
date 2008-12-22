module Jekyll
  
  class IncludeTag < Liquid::Tag
    def initialize(tag_name, file, tokens)
      super
      @file = file.strip
    end
    
    def render(context)
      if @file !~ /^[a-zA-Z0-9_\/\.-]+$/ || @file =~ /\.\// || @file =~ /\/\./
        return "Include file '#{@file}' contains invalid characters or sequences"
      else
        return Jekyll::Include.new(@file).content
      end
    end
  end
  
end

Liquid::Template.register_tag('include', Jekyll::IncludeTag)