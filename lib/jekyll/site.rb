module Jekyll
  
  class Site
    attr_accessor :source, :dest, :ignore_pattern
    attr_accessor :layouts, :posts, :categories, :settings
    attr_accessor :options
    
    # Initialize the site
    #   +source+ is String path to the source directory containing
    #            the proto-site
    #   +dest+ is the String path to the directory where the generated
    #          site should be written
    #   +ignore_pattern+ is a regular expression String which
    #                    specifies a group of files which should not
    #                    be processed or appear in the generated
    #                    site. A regular expression matching any files
    #                    beginning with a `.' or a `_', other than
    #                    `.htaccess' and `_posts', will automatically
    #                    be appended to this parameter.
    #
    # Returns <Site>
    def initialize(source, dest, ignore_pattern = '^$')
      self.source = source
      self.dest = dest
      self.ignore_pattern = Regexp.new(ignore_pattern + '|^\.(?!htaccess).*$|^_(?!posts).*$')
      self.layouts = {}
      self.posts = []
      self.categories = Hash.new { |hash, key| hash[key] = Array.new }
      self.read_settings
      self.options = {}

      config_file_path = File.join(self.source, '.jekyllrc')
      if File.exists?(config_file_path)
        self.options = YAML.load(File.read(config_file_path))
      end
      
      self.options['layouts_path']  ||= File.join(self.source, '_layouts')
      self.options['includes_path'] ||= File.join(self.source, '_includes')
    end
    
    # Do the actual work of processing the site and generating the
    # real deal.
    #
    # Returns nothing
    def process
      self.read_layouts
      self.transform_pages
      if options['also_copy']
        self.transform_pages('', options['also_copy'])
      end
      self.write_posts
    end

    # read settings from _site.yaml
    def read_settings
      file = File.join(self.source, "_site.yaml")
      if File.exist?(file)
        self.settings = File.open(file) { |f| YAML::load(f) }
      else
        self.settings = {}
      end
    end
    
    # Read all the files in <source>/_layouts into memory for later use.
    #
    # Returns nothing
    def read_layouts
      base = options['layouts_path']
      entries = []
      Dir.chdir(base) { entries = filter_entries(Dir['*.*']) }
      
      entries.each do |f|
        name = f.split(".")[0..-2].join(".")
        self.layouts[name] = Layout.new(base, f)
      end
    rescue Errno::ENOENT => e
      # ignore missing layout dir
    end
    
    # Read all the files in <base>/_posts and create a new Post object with each one.
    #
    # Returns nothing
    def read_posts(dir)
      base = File.join(self.source, dir, '_posts')
      entries = []
      Dir.chdir(base) { entries = filter_entries(Dir['**/*']) }

      # first pass processes, but does not yet render post content
      entries.each do |f|
        if Post.valid?(f)
          post = Post.new(self.source, dir, f)

          if post.published
            self.posts << post
            post.categories.each { |c| self.categories[c] << post }
          end
        end
      end

      self.posts.sort!
      
      # second pass renders each post now that full site payload is available
      self.posts.each_with_index do |post, idx|
        post.previous = posts[idx - 1] unless idx - 1 < 0
        post.next = posts[idx + 1] unless idx + 1 >= posts.size
        post.render(self.layouts, site_payload)
      end
      
      self.categories.values.map { |cats| cats.sort! { |a, b| b <=> a} }
    rescue Errno::ENOENT => e
      # ignore missing layout dir
    end
    
    # Write each post to <dest>/<year>/<month>/<day>/<slug>
    #
    # Returns nothing
    def write_posts
      self.posts.each do |post|
        post.write(self.dest)
      end
    end
    
    # Copy all regular files from <source> to <dest>/ ignoring
    # any files/directories that match the regular expression supplied
    # when creating this.
    #   The +dir+ String is a relative path used to call this method
    #            recursively as it descends through directories
    #
    # Returns nothing
    def transform_pages(dir = '', source = self.source)
      base = File.join(source, dir)
      entries = filter_entries(Dir.entries(base))
      directories = entries.select { |e| File.directory?(File.join(base, e)) }
      files = entries.reject { |e| File.directory?(File.join(base, e)) }

      [directories, files].each do |entries|
        # we need to make sure to process _posts *first* otherwise they 
        # might not be available yet to other templates as {{ site.posts }}
        if entries.include?('_posts')
          entries.delete('_posts')
          read_posts(dir)
        end
        entries.each do |f|
          if File.symlink?(File.join(base, f))
            # preserve symlinks
            FileUtils.mkdir_p(File.join(self.dest, dir))
            File.symlink(File.readlink(File.join(base, f)),
                         File.join(self.dest, dir, f))
          elsif File.directory?(File.join(base, f))
            next if self.dest.sub(/\/$/, '') == File.join(base, f)
            transform_pages(File.join(dir, f), source)
          else
            first3 = File.open(File.join(source, dir, f)) { |fd| fd.read(3) }
        
            # if the file appears to have a YAML header then process it as a page
            if first3 == "---"
              # file appears to have a YAML header so process it as a page
              page = Page.new(source, dir, f)
              page.add_layout(self.layouts, site_payload)
              page.write(self.dest)
            else
              # otherwise copy the file without transforming it
              FileUtils.mkdir_p(File.join(self.dest, dir))
              FileUtils.cp(File.join(source, dir, f), File.join(self.dest, dir, f))
            end
          end
        end
      end
    end

    # Constructs a hash map of Posts indexed by the specified Post attribute
    #
    # Returns {post_attr => [<Post>]}
    def post_attr_hash(post_attr)
      # Build a hash map based on the specified post attribute ( post attr => array of posts )
      # then sort each array in reverse order
      hash = Hash.new { |hash, key| hash[key] = Array.new }
      self.posts.each { |p| p.send(post_attr.to_sym).each { |t| hash[t] << p } }
      hash.values.map { |sortme| sortme.sort! { |a, b| b <=> a} }
      return hash
    end

    # The Hash payload containing site-wide data
    #
    # Returns {"site" => {"time" => <Time>,
    #                     "posts" => [<Post>],
    #                     "categories" => [<Post>],
    #                     "topics" => [<Post>] }}
    def site_payload
      all_posts = self.posts.sort { |a,b| b <=> a }
      latest_posts = all_posts[0..2]
      older_posts = all_posts[3..7]
      rss_posts = all_posts[0..25]
      
      {"site" => self.settings.merge({
        "time" => Time.now, 
        "posts" => all_posts,
        "latest_posts" => latest_posts,
        "older_posts" => older_posts,
        "rss_posts" => rss_posts,
        "categories" => post_attr_hash('categories'),
        "topics" => post_attr_hash('topics')
      })}
    end

    # Filter out any files/directories that are hidden or backup files (start
    # with "." or "#" or end with "~") or contain site content (start with "_")
    # unless they are "_posts" directories or web server files such as
    # '.htaccess'
    def filter_entries(entries)
      entries = entries.reject do |e|
        unless ['_posts', '.htaccess'].include?(e)
          # Reject backup/hidden
          ['.', '_', '#'].include?(e[0..0]) or e[-1..-1] == '~'
        end
      end
      entries = entries.reject { |e| ignore_pattern.match(e) }
    end

  end
end
