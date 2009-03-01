module Jekyll
  class MarkdownBlock < Liquid::Block
    include Liquid::StandardFilters
    def render(context)
      Maruku.new(super(context).join).to_html
    end
  end
end

Liquid::Template.register_tag('markdown', Jekyll::MarkdownBlock)
