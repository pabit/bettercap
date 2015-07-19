=begin

BETTERCAP

Author : Simone 'evilsocket' Margaritelli
Email  : evilsocket@gmail.com
Blog   : http://www.evilsocket.net/

This project is released under the GPL 3 license.

=end
module Logger
  class << self
    attr_accessor :logfile

    def error(message)
      write(formatted_message(message, "E").red)
    end

    def info(message)
      write(formatted_message(message, "I").yellow)
    end

    def debug(message)
      # write(formatted_message(message, "D").light_black)
    end

    def write(message)
      puts message
      if @logfile != nil
        f = File.open(@logfile,"a+t");
        f.puts( message.gsub( /\e\[(\d+)(;\d+)*m/, '') + "\n")
        f.close
      end
    end

    private
    def formatted_message(message, message_type)
      "[#{message_type}] #{message}"
    end
  end
end
