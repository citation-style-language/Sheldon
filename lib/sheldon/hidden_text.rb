require 'base64'

module Sheldon
  module HiddenText
    BARRIER = '::sheldon::'

    def hide(txt)
      enc = Base64.encode64(txt).strip
      enc = BARRIER + enc.gsub("\n", "\n#{BARRIER}"
    end

    def seek()
    end
  end
end
