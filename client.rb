require 'socket'
require './string'

class Client
  def initialize (server, login_params)
    @DEBUG = true

    @default_channel = nil
    @channels = []
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
    case msg
    when ''
      return
    when /\A\/JOIN/i
      unless msg.match(/\/JOIN #/i)
        puts 'Channel name must begin with a \'#\'.'.yellow
        return
      end
      channel = msg.sub(/^[^#]*/, '').match(/(?<=#)\S+/)[0].downcase
      @default_channel = channel
      @channels << channel
      puts "Default Channel now ##{@default_channel}".green
      @server.puts msg.sub(/\A\//, '')
    when /\A\/MAIN/i
      @default_channel = msg.match(/(?<=#)\S+/)[0]
      puts "Default Channel now ##{@default_channel}".green
    when /\A\//
      @server.puts msg.sub(/\A\//, '')
    else
      @server.puts "PRIVMSG ##{@default_channel} :" + msg
    end
  end

  def start_listen_thread
    @response = Thread.new do
      loop do
        server_msg = @server.gets.chomp
        server_msg_type = test_server_msg server_msg
        puts server_msg if server_msg_type == 'default'
        puts server_msg.red if server_msg_type == 'private'
        puts server_msg.green if server_msg_type == 'server'
      end
    end
  end

  def start_send_thread
    @request = Thread.new do
        @server.puts "NICK #{@login[:nick]}"
        puts "NICK #{@login[:nick]}" if @DEBUG
      loop do
        user_msg = gets.chomp
        if user_msg == "exit"
          puts 'Goodbye!'
          @server.close
          exit
        else
          parse_and_send_user_msg user_msg
        end
      end
    end
  end

  def test_server_msg msg
    case
      when msg.match(/\APING/)
        @server.puts "#{msg.sub(/PING/, 'PONG')}"
        return 'ping'
      when msg.match(/\APRIVATE from/)
        return 'private'
      when msg.match(/\ASERVER: /)
        return 'server'
      else
        'default'
    end
  end
end

#host = 'irc.freenode.net'
host = 'localhost'
port = 6667

server = TCPSocket.open host, port

puts "Nickname?"
nickname = gets.chomp
login_params = {nick: nickname, mode: 0, real_name: 'Parker Emerson'}

Client.new server, login_params