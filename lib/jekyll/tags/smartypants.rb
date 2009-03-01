require 'jekyll/filters'

module Jekyll
  class SmartypantsBlock < Liquid::Block
    include Liquid::StandardFilters
    def render(context)
      Smartypants.educate_string(super(context).join)
    end
  end

  # Maruku, inexplicably, offers no way to access its Smartypants
  # implementation outside of the Markdown interface. So here's a hack.
  class Smartypants; end
  class << Smartypants
    include MaRuKu::In::Markdown::SpanLevelParser
    include MaRuKu::Helpers
    def educate_string(s)
      educate([s]).map{ |x| x.to_html_entity rescue x }.join
    end
  end
end

Liquid::Template.register_tag('educate', Jekyll::SmartypantsBlock)
