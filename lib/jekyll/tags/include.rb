module Jekyll
  
  class IncludeTag < Liquid::Tag
    Syntax = /from\s+(#{Liquid::VariableSignature}+)/
    
    def initialize(tag_name, markup, tokens)
      super
      if markup =~ Syntax
        @variable = $1
        @use_context = 1
      else
        @file = markup.strip
        @use_context = 0
      end
    end
    
    def render(context)
      if @use_context == 1
        @file = context[@variable]
      end

      if @file !~ /^[a-zA-Z0-9_\/\.-]+$/ || @file =~ /\.\// || @file =~ /\/\./
        return "Include file '#{@file}' contains invalid characters or sequences"
      end

      if Jekyll.site && Jekyll.site.options
         path = Jekyll.site.options['include_path']
      else
         path = File.join(Jekyll.source, '_includes')
      end

      Dir.chdir(path) do
        choices = Dir['**/*'].reject { |x| File.symlink?(x) }
        if choices.include?(@file)
          source = File.read(@file)
          partial = Liquid::Template.parse(source)
          context.stack do
            partial.render(context, [Jekyll::Filters])
          end
        else
          "Included file '#{@file}' not found in _includes directory"
        end
      end
    end
  end
  
end

Liquid::Template.register_tag('include', Jekyll::IncludeTag)
