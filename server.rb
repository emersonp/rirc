require 'socket'
require './string'

class Server
  def initialize ip, port
    @server = TCPServer.open ip, port
    @connections = Hash.new
    @rooms = Hash.new
    @clients = Hash.new
    @client_status = Hash.new
    @connections[:server] = @server
    @connections[:rooms] = @rooms
    @connections[:clients] = @clients
    @connections[:status] = @client_status

    run_server
  end

  def run_server
    Thread.new {
      loop_count = 0
      puts 'Server launched.'
      loop do
        loop_count += 1
        #puts "\nPing Loop Count: #{loop_count}"
        @connections[:clients].each do |nick_name, client|
          @connections[:status][client] = false
          begin
            client.puts "PING #{Time.now.to_s}"
            #puts "Pinged #{client}/#{nick_name} at #{Time.now.to_s}"
          rescue Exception => myException
            #puts "Exception rescued : #{myException}"
            @connections[:clients].delete(nick_name)
            @connections[:status].delete(nick_name)
          end
        end
        sleep 20
        @connections[:clients].each do |nick_name, client|
          unless @connections[:status][client]
            client.close
          end
        end
      end
    }

    loop {
      Thread.new @server.accept do |client|
        @connections[:status][client] = true
        nick_name = false
        until nick_name
          client.puts 'SERVER: Please enter a /NICK'
          user_input = client.gets.chomp()
          if user_input =~ /\ANICK\s+/
            nick_name = user_input.sub(/\ANICK\s+/, '').to_sym
          end
          @connections[:clients].each do |other_name, other_client|
            if nick_name == other_name || client == other_client
              client.puts 'SERVER: This nickname already exists.'
              nick_name = false
              break
            end
          end
        end
        puts "#{nick_name} #{client}"
        @connections[:clients][nick_name] = client
        client.puts "SERVER: Welcome to the server, #{nick_name}"
        listen_user_msgs nick_name, client
      end
    }.join
  end

  def listen_user_msgs user_name, client
    loop do
      readfds = nil
      msg = nil
      begin
        readfds, writefds, exceptfds = select([client], nil, nil, 0.1)
        #p :r => readfds, :w => writefds, :e => exceptfds

        if readfds
          msg = client.gets
        end
      end

      process_user_msgs msg, user_name, client if msg
    end
  end

  def process_user_msgs msg, nick_name, client
    puts "#{client}/#{nick_name}: #{msg}"
    case msg
      when /\AJOIN/i
        add_user_to_channel msg, nick_name, client
      when /\APONG/i
        @connections[:status][client] = true
      when /\APRIVMSG/i
        process_private_message msg, nick_name, client
      when /\ALIST/i
        list_all_channels client
      when /\ANAMES/i
        list_all_users msg, client
      else
        @connections[:clients].each do |other_name, other_client|
          unless other_name == nick_name
            other_client.puts "#{nick_name.to_s}: #{msg}"
          end
        end
    end
  end

  def add_user_to_channel msg, nick_name, client
    channel = msg.sub(/^[^#]*/, '').match(/(?<=#)\S+/)[0].downcase
    puts "Channel = #{channel}, nick_name: #{nick_name}, client: #{client}"
    if @connections[:rooms][channel]
      @connections[:rooms][channel] << nick_name
    else
      @connections[:rooms][channel] = [nick_name]
    end
    client.puts "You joined channel ##{channel}"
    broadcast_to_all channel, "[#{channel}] #{nick_name} joined the channel."
    puts "Channel Members: #{@connections[:rooms][channel]}"
  end

  def broadcast_to_all channel, msg
    @connections[:clients].each do |nick_name, client|
      client.puts msg if @connections[:rooms][channel].include?(nick_name)
    end
  end

  def list_all_channels client
    client.puts "SERVER: The channels on this server are:\n##{@connections[:rooms].keys.join("\n#")}"
  end

  def list_all_users msg, client
    list_of_users = []
    if msg =~ /(?<=#)\S+/i
      channel = msg.sub(/^[^#]*/, '').match(/(?<=#)\S+/)[0].downcase
      list_of_users = @connections[:rooms][channel]
      client.puts "SERVER: List of users in channel ##{channel}:"
    else
      list_of_users = @connections[:clients].keys
      client.puts 'SERVER: List of users on server:'
    end
    client.puts list_of_users.join("\n")
  end

  def process_private_message msg, nick_name, client
    msg = msg.sub(/\APRIVMSG /i, '')
    if msg[0] == '#'
      channel = msg.match(/(?<=#)\S+/)[0]
      puts "Process_Private_Message: #{channel}"
      unless @connections[:rooms][channel]
        client.puts "SERVER: Channel '#{channel}' does not exist."
        return
      end
      msg = msg[1..-1].sub(channel, '')
      @connections[:clients].each do |other_name, other_client|
        if @connections[:rooms][channel].include?(nick_name) &&
               @connections[:rooms][channel].include?(other_name) &&
               nick_name != other_name
          other_client.puts "[#{channel}] #{nick_name}: #{msg.to_s}"
        end
      end
    elsif @connections[:clients].keys.include?(target_name = msg.match(/\A\S+/)[0].to_sym)
      puts "#{target_name.to_s} targeted with private message."
      @connections[:clients].each do |other_name, other_client|
        if target_name == other_name
          other_client.puts "PRIVATE from #{nick_name}: #{msg.sub(msg.match(/\A\S+/)[0] + ' ', '')}"
        end
      end
    else
      client.puts "SERVER: '#{msg.match(/\A\S+/)[0]}' not recognized as nickname. Use /LIST to see all participants in chat."
    end
  end
end

server = Server.new 'localhost', 6667