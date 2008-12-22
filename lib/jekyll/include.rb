module Jekyll

  class Include
    include Convertible
    
    attr_accessor :ext, :content
    
    # Initialize a new Include.
    #   +name+ is the String filename of the include file
    #
    # Returns <Include>
    def initialize(name)
      @file = name
      self.ext = File.extname(name)
      self.content = raw_content
      self.transform
    end
    
    # Load raw content from file
    #
    # Returns a string
    def raw_content
      Dir.chdir(Jekyll.site.options['includes_path']) do
        choices = Dir['**/*'].reject { |x| File.symlink?(x) }
        if choices.include?(@file)
          File.read(@file)
        else
          "Included file '#{@file}' not found in _includes directory"
        end
      end
    end
    
  end

end