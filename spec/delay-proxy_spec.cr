require "./spec_helper"
require "http/server"

describe "delay-proxy" do
  it "can redirect HTTP" do
    http_server = HTTP::Server.new do |context|
      context.response.content_type = "text/plain"
      context.response.print "Hello world!"
    end

    spawn do
      address = http_server.bind_tcp 8080
      puts "Listening on http://#{address}"
      http_server.listen
    end

    proxy = nil
    spawn do
      proxy = Process.new("./bin/delay-proxy :8080", shell: true, output: :inherit)
    end

    sleep(1)
    response = HTTP::Client.get "http://localhost:1234"
    response.status_code.should eq(200)      # => 200
    response.body.should eq("Hello world!")
    proxy.not_nil!.signal(:term)
  end
end
