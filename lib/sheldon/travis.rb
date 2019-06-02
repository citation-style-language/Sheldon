require "sheldon/version"

require 'dotenv/load'

#require 'reverse_markdown'
require 'json'
require 'base64'
require 'cgi'
require 'citeproc'
require 'csl'
require 'csl/styles'
require 'diffy'
require 'open-uri'
require 'optparse'
require 'ostruct'

module Sheldon
  Asset = Struct.new(:path, :source, keyword_init: true)
  Style = Struct.new(:path, :baseline, keyword_init: true)

  class EnvironmentError < StandardError
    attr_reader :fatal

    def initialize(fatal = true)
      @fatal = fatal
    end
  end

  class Chatter
    def initialize
      raise EnvironmentError.new(false), 'TRAVIS_PULL_REQUEST is not set' if (ENV['TRAVIS_PULL_REQUEST'] || 'false') == 'false'
      raise EnvironmentError.new(false), 'Sheldon cannot be run from the master branch' if `git rev-parse --abbrev-ref HEAD`.strip() == 'master'
      raise EnvironmentError.new, 'TRAVIS_COMMIT_RANGE is not set' if ENV['TRAVIS_COMMIT_RANGE'].to_s == ''
      raise EnvironmentError.new, 'TRAVIS_REPO_SLUG is not set' if ENV['TRAVIS_REPO_SLUG'].to_s == ''
      raise EnvironmentError.new, 'TRAVIS_PULL_REQUEST is not a number' unless ENV['TRAVIS_PULL_REQUEST'] =~ /^[0-9]+$/
      raise EnvironmentError.new, 'TRAVIS_BUILD_ID is not a number' unless ENV['TRAVIS_BUILD_ID'].to_s =~ /^[0-9]+$/
      raise EnvironmentError.new, 'Sheldon must be ran from the project root' unless File.directory?('.git')

      @verbose = false
      OptionParser.new do |opts|
        opts.banner = "Usage: sheldon [options]"

        opts.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
          @verbose = v
        end
      end.parse!

      @repo = ENV['TRAVIS_REPO_SLUG']
      @pr = Integer(ENV['TRAVIS_PULL_REQUEST'])
      @build = Integer(ENV['TRAVIS_BUILD_ID'])

      @changed = []
      `git diff --name-status $TRAVIS_COMMIT_RANGE`.split(/\n/).each{|change|
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
    end

    def report(msg)
      #vars[:build_url] = "https://travis-ci.org/#{@repo}/builds/#{@build}"
      #puts template if @verbose
      #puts vars if @verbose

      #msg = ERB.new(File.read(template)).result(OpenStruct.new(vars).instance_eval { binding })
      #puts msg if @verbose

      #@gh.add_comment(@repo, @pr, msg)

      return if msg == ''
      puts "sheldon:#{msg.to_json} ".split('').collect{|c| "#{c}\b"}.join('')
    end

    def run
      return if failure()

      case @repo.split('/')[1]
        when 'styles'
          details = styles_passed()
        when 'locales'
          details = locales_passed()
      end

      report(details)
    end

    def failure
      return false unless File.file?('spec/sheldon/travis.json')
      travis = JSON.load(File.open('spec/sheldon/travis.json'))

      failures = []
      travis['examples'].each{|ex|
        next if ex['status'] == 'passed'

        failures << ''
        failures[-1] += '<b>' + CGI::escapeHTML(ex['full_description'].gsub(/\e\[([;\d]+)?m/, '')) + '</b>'
        failures[-1] += "\n```\n" + ex['exception']['message'].gsub(/\e\[([;\d]+)?m/, '').strip() + "\n```\n"
      }

      if failures.length == 0
        puts "No failures found" if @verbose
        return false
      end

      puts "#{failures.length} failures found" if @verbose

      report("<details><summary>#{failures.length} test#{failures.length == 1 ? '' : 's'} failed</summary>\n\n#{failures.join("\n")}\n\n</details>")
      return true
    end

    def styles_passed
      styles = @changed.select{|asset| asset.path.end_with?('.csl') }.collect{|asset| Style.new(path: asset.path, baseline: asset.source && `git show master:#{asset.source}`) }
      if styles.empty?
        puts "No styles changed" if @verbose
        return
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
      max = 10
      if styles.length > max
        comments = "#{styles.length} styles changed, showing #{max}\n\n"
        styles = styles.take(max)
      end

      items = JSON.load(File.open('spec/sheldon/items.json'))

      styles.each{|style|
        comments += '<details>'

        rendered = render(items, style.path)
        baseline = style.baseline ? render(items, style.baseline) : nil

        if baseline && rendered == baseline
          status = 'modified style; unchanged output for sample items'
        elsif baseline
          status = 'modified style'
        else
          status = 'new'
        end

        comments += "<summary>#{style.path} (#{status})</summary>\n"
        comments += "<blockquote>#{rendered}</blockquote>\n"

        if baseline && baseline != rendered
          comments += "\n```diff\n"
          comments += Diffy::Diff.new(baseline, rendered).to_s
          comments += "\n```\n"
        end

        comments += '</details>'
      }

      return comments
    end

    def locales_passed
      return ''
    end

    def render(items, style)
      result = ''
      cp = CiteProc::Processor.new(style: style, format: 'html')
      cp.import(items)

      items.each_slice(2){|citation|
        result += cp.process(citation.map{|i| { 'id' => i['id'] } }) + "<br/>\n"
      }

      result += "<hr/>\n"

      cp.bibliography.each{|line| result += line + "<br/>\n" }

      return result
    end
  end
end