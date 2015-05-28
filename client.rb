require 'socket'
require './string'

class Client
  def initialize (server, login_params)
    @DEBUG = true

    @channel_main = "practicing-ruby-testing"
    @channels = [] << @channel_main
    @login = login_params
    @server = server
    @request = nil
    @respond = nil

    start_listen_thread
    start_send_thread

    @request.join
    @respond.join
  end

  def parse_and_send_user_msg msg
    if /\A\// =~ msg
      @server.puts msg.sub(/\A\//, '')
    else
      @server.puts "PRIVMSG ##{@channel_main} :" + msg
    end
  end

  def start_listen_thread
    @response = Thread.new do
      loop do
        server_msg = @server.gets.chomp
        server_msg_type = test_server_msg server_msg
        puts server_msg if server_msg_type == "default"
      end
    end
  end

  def start_send_thread
    @request = Thread.new do
        @server.puts "NICK #{@login[:nick]}"
        puts "NICK #{@login[:nick]}" if @DEBUG
        #@server.puts "USER #{@login[:nick]} #{@login[:mode]} * : #{@login[:real_name]}"
        #@server.puts "JOIN #practicing-ruby-testing"
      loop do
        user_msg = gets.chomp
        if user_msg == "exit"
          puts "Goodbye!"
          exit
        else
          puts "Sending: #{user_msg}".pink
          parse_and_send_user_msg user_msg
        end
      end
    end
  end

  def test_server_msg msg
    case
      when msg.match(/\APING/)
        @server.puts "#{msg.sub(/PING/, 'PONG')}"
        return "ping"
      else
        "default"
    end
  end
end

#host = 'irc.freenode.net'
host = 'localhost'
port = 6667

server = TCPSocket.open host, port

puts "Nickname?"
nickname = gets.chomp
login_params = {nick: nickname, mode: 0, real_name: "Parker Emerson"}

Client.new server, login_params