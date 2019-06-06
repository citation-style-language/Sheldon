require 'base64'

module Sheldon
  module HiddenText
    MARKER = ':sheldon:'
    REVERSE_LINE_FEED = "\033[1A"

    def hide(txt)
      line_length = 40
      enc = Base64.strict_encode64(txt).scan(/.{1,#{line_length}}/)
      # erase last line
      enc << " " * enc.max_by(&:length).length

      enc.each{|line|
        puts "#{MARKER}#{line}"
        print REVERSE_LINE_FEED
      }
    end
    module_function :hide

    def seek(txt)
      enc = txt.gsub(REVERSE_LINE_FEED, '').split("\n").select{|line| line.start_with?(MARKER) }.collect{|line| line.sub(MARKER, '') }.join('').strip
      return enc == '' ? '' : Base64.decode64(enc)
    end
    module_function :seek
  end
end
