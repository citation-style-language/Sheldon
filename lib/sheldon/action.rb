require 'octokit'
require 'json'
require 'ostruct'
require './lib/sheldon/template'
require 'faraday'

module Sheldon
  Asset = Struct.new(:path, :source, keyword_init: true)
  Style = Struct.new(:path, :baseline, :default_locale, keyword_init: true)

  class GitHubAction
    def initialize
      throw "Don't call me on the master branch" if ENV['GITHUB_REF'] == 'refs/heads/master'

      @message = nil
      @token = nil
      @verbose = false
      OptionParser.new do |opts|
        opts.banner = "Usage: sheldon [options]"
        opts.on('-w', '--welcome', 'Welcome the PR') do |v|
          throw 'Already handling #{@message}' if @message
          @message = 'welcome'
        end
        opts.on('-STATUS', '--status=STATUS', 'Report success/failure') do |v|
          throw 'Already handling #{@message}' if @message
          @message = v
        end
        opts.on('-tTOKEN', '--token=TOKEN', 'GitHub token') do |v|
          @token = v
        end
        opts.on('-v', '--[no-]verbose', 'Verbose logging') do |v|
          @verbose = v
        end
      end
      throw "Unexpected handler #{@message}" unless %w{welcome failed success}.include?(@action)
      throw "No token passed" unless @token
      throw "Only call me on a GitHub pull request" unless ENV['GITHUB_EVENT_NAME'] == 'pull_request'

      @github = Octokit::Client.new(access_token: @token)
      @event = JSON.load(ENV['GITHUB_EVENT_PATH'], object_class: OpenStruct)
      @repo = ENV['GITHUB_REPOSITORY'].split('/').last
      @build_url = 'https://github.com/#{ENV['GITHUB_REPOSITORY']}/actions/runs/#{ENV['GITHUB_RUN_ID']}',

      if @message == 'welcome'
        self.welcome()
      else
        self.report()
      end
    end

    def welcome
      raise "Only call me when a new GitHub PR is opened" unless @event.action == 'opened'

      template = Template.load(File.join(@repo, 'pull_request_opened.md.erb')

      @github.add_comment(ENV['GITHUB_REPOSITORY'], @event.number, template.render())
    end

    def report()
      template = Template.load(File.join(@repo, 'build_#{@message}.md.erb')

      @changed = []

      commits = JSON.parse(Faraday.get(@event.pull_request.commits_url), object_class: OpenStruct)
      `git diff --name-status #{commits.first.sha}^..#{commits.last.sha}`.split(/\n/).each{|change|
        case change[0]
          when 'M', 'A'
            path = change.split(/\t/)[1]
            @changed << Asset.new(path: path, source: change[0] == 'M' ? path : nil )
            puts "Changed: #{path}" if @verbose

          when 'D'
            next

          when 'R'
            action, from, to = change.split(/\t/)
            @changed << Asset.new(path: to, source: from)
            puts "Renamed: #{to}" if @verbose

          else
            throw "Unexpected change of type #{change[0]}"

        end
      }

      return if failure()

      case @repo
        when 'styles'
          vars = {
            'build_url': @build_url,
            'build_details': styles_passed(),
          }
        when 'locales'
          vars = {
            'build_url': @build_url,
            'build_details': locales_passed()
          }
        else
          raise ValueError("Unexpected repo #{@repo}")
      end
      github.add_comment(ENV['GITHUB_REPOSITORY'], @event.number, template.render(vars))
    end

    def locales_passed
      return ''
    end

    def render(items, style, locale)
      locale = File.join(CSL::Locale.root, "locales-#{locale}.xml") if locale
      puts ({ style: (style =~ /^</ ? :baseline : style), locale: locale }).inspect if @verbose

      result = ''
      cp = CiteProc::Processor.new(style: style, locale: locale, format: 'html')
      cp.import(items)

      items.each_slice(2){|citation|
        result += cp.process(citation.map{|i| { 'id' => i['id'] } }) + "<br/>\n"
      }

      bibliography = cp.bibliography
      if bibliography
        result += "<hr/>\n"
        bibliography.each{|line| result += line + "<br/>\n" }
      end

      return result
    end

    def styles_passed
      styles = @changed.select{|asset| asset.path.end_with?('.csl') }.collect{|asset| Style.new(path: asset.path, baseline: asset.source && `git show master:#{asset.source}`) }
      if styles.empty?
        puts "No styles changed" if @verbose
        return ''
      end
      puts "#{styles.length} styles changed" if @verbose

      comments = ''

      styles.sort!{|a, b|
        da = File.dirname(a.path)
        db = File.dirname(b.path)
        if da.length == db.length
          # they're both dependents, or both independents, sort on name
          a.path <=> b.path
        else
          # if one is dependent and the other is not, prioritize independents at the root level
          da.length <=> db.length
        end
      }
      max = Integer(ENV['SHELDON_CHANGED_SHOW_MAX'] || 10)
      comments = "#{styles.length} styles changed, showing #{max}\n\n" if styles.length > max

      items = JSON.load(File.open('spec/sheldon/items.json'))

      styles.each_with_index{|style, i|
        File.open(style.path) { |f| style.default_locale = default_locale(f) }

        begin
          rendered = render(items, style.path, style.default_locale)
          baseline = style.baseline ? render(items, style.baseline, default_locale(style.baseline)) : nil
        rescue
          rendered = nil
        end

        next if rendered && i >= max

        baseline = nil if rendered.nil?

        comments += '<details>'

        if baseline && rendered == baseline
          status = 'modified style; unchanged output for sample items'
        elsif baseline
          status = 'modified style'
        elsif rendered
          status = 'new'
        else
          status = 'rendering failure'
        end

        comments += "<summary>#{style.path} (#{status})</summary>\n"
        comments += "<blockquote>#{rendered}</blockquote>\n" if rendered

        if baseline && baseline != rendered
          comments += "\n```diff\n"
          comments += Diffy::Diff.new(baseline, rendered).to_s
          comments += "\n```\n"
        end

        comments += '</details>'
      }

      puts comments if @verbose
      return comments
    end
  end
end
