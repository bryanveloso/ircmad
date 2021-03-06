require "ircmad/web_socket/buffer"

class Ircmad
  class WebSocket
    include Configurable

    def initialize(&block)
      instance_eval(&block) if block_given?
    end

    def subscribers
      @subscribers ||= {}
    end

    def host
      '0.0.0.0'
    end

    # http://qiita.com/items/bf47e254d662af1294d8#
    def port
      unless @port || config[:port]
        s = TCPServer.open(0)
        @port = s.addr[1]
        s.close
      end
      @port || config[:port]
    end

    def run!
      puts "Starting WebSocket server on #{host}:#{port}"

      Ircmad.get_channel.subscribe do |msg|
        buffer << msg
      end

      EM::WebSocket.start(:host => host, :port => port) do |socket|
        socket.onopen do |sock|
          buffer.each do |msg|
            socket.send msg.to_json
          end
          subscribers[socket.object_id] = Ircmad.get_channel.subscribe { |msg| socket.send msg.to_json }
        end

        socket.onclose do |sock|
          Ircmad.get_channel.unsubscribe(subscribers[socket.object_id])
        end

        socket.onmessage do |msg|
          Ircmad.post_channel << msg
        end

        socket.onerror do |error|
          puts error
        end
      end
    end

    def buffer
      @buffer ||= Buffer.new
    end
  end
end
