require "test_helper"

class TradeRepublicWebsocketTest < ActiveSupport::TestCase
  test "opens a CONNECT tunnel through the configured proxy" do
    server = TCPServer.new("127.0.0.1", 0)
    received = Queue.new
    serving = Thread.new do
      client = server.accept
      received << client.gets
      while (line = client.gets)
        break if line == "\r\n"
      end
      client.write("HTTP/1.0 200 Connection established\r\n\r\n")
      client.close
    end

    websocket = Provider::TradeRepublicWebsocket.new(headers: {}, timeout: 2)
    websocket.stubs(:proxy_uri).returns(URI("http://127.0.0.1:#{server.addr[1]}"))
    tunnel = websocket.send(:open_tunnel)

    assert_equal "CONNECT api.traderepublic.com:443 HTTP/1.1\r\n", received.pop
    tunnel.close
  ensure
    serving&.kill
    server&.close
  end

  test "rejects a proxy response that is not a successful CONNECT" do
    server = TCPServer.new("127.0.0.1", 0)
    serving = Thread.new do
      client = server.accept
      while (line = client.gets)
        break if line == "\r\n"
      end
      client.write("HTTP/1.1 403 Forbidden\r\n\r\n")
      client.close
    end

    websocket = Provider::TradeRepublicWebsocket.new(headers: {}, timeout: 2)
    websocket.stubs(:proxy_uri).returns(URI("http://127.0.0.1:#{server.addr[1]}"))

    assert_raises(Provider::TradeRepublicClient::TransientProviderError) do
      websocket.send(:open_tunnel)
    end
  ensure
    serving&.kill
    server&.close
  end

  test "connects directly when no proxy is configured" do
    socket = stub
    Socket.stubs(:tcp).with(Provider::TradeRepublicWebsocket::HOST, 443, connect_timeout: 5).returns(socket)
    websocket = Provider::TradeRepublicWebsocket.new(headers: {}, timeout: 5)
    websocket.stubs(:proxy_uri).returns(nil)

    assert_same socket, websocket.send(:open_tunnel)
  end
end
