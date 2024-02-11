require "socket"
require "colorize"
require "log"

DEFAULT_DELAY = 200_i64
DEFAULT_PORT = 1234
DELAY_VARIANCE = 0.1
SOCKET_BUFFER_SIZE = 1024 * 1024 * 8 # 8K
HELP_BANNER = "Use delay-proxy [target-host:]port [proxy-port] [delay in milliseconds]"
VERSION = {{ `shards version "#{__DIR__}"`.chomp.stringify }}

def forward_socket(src : IO, dst : IO, label, delay : Int)
  buffer = Bytes.new(SOCKET_BUFFER_SIZE)
  while !src.closed?
    n = src.read(buffer)
    next if n.zero?

    rnd_delay = random_delay(delay)
    Log.info { "#{label} #{n} bytes ⌛#{rnd_delay}ms" }
    dst.write(buffer[0...n])
    dst.flush
  end
end

def random_delay(delay : Int)
  variance = (delay * DELAY_VARIANCE).to_i64

  min_delay = delay - variance
  max_delay = delay + variance
  rnd_delay = rand(min_delay..max_delay)
  nanoseconds = (rnd_delay % 1000) * 1_000_000

  sleep(Time::Span.new(nanoseconds: rnd_delay * 1_000_000))

  rnd_delay
end

struct LogFormat < Log::StaticFormatter
  def run
    message
  end
end

Log.setup(:info, Log::IOBackend.new(formatter: LogFormat))

def parse_host_port(_nil : Nil, default_port : Int)
  {"localhost", default_port}
end

def parse_host_port(str : String, default_port : Int? = nil)
  parts = str.split(":")
  host = parts[0].blank? ? "localhost" : parts[0]
  port = parts[1]?.try(&.to_i) || default_port

  {host, port}
end

def parse_options
  abort(HELP_BANNER) if ARGV.size < 1
  if ARGV.includes?("--help") || ARGV.includes?("-h")
    puts(HELP_BANNER)
    exit
  end

  if ARGV.includes?("--version")
    puts(VERSION)
    exit
  end

  target_host, target_port = parse_host_port(ARGV[0])
  proxy_port = ARGV[1]?.try(&.to_i) || DEFAULT_PORT
  abort("Specify the target port.") if target_port.nil?

  delay = ARGV[2]? ? ARGV[2].to_i64 : DEFAULT_DELAY

  {target_host: target_host, target_port: target_port,
   proxy_port: proxy_port, delay: delay}
end

def handle_connection(proxy_socket : Socket, target_host : String, target_port : Int, delay : Int64)
  TCPSocket.open(target_host, target_port) do |target_socket|
    Log.info { "Proxy connected to target" }
    wait = Channel(Nil).new(2)
    spawn do
      forward_socket(proxy_socket, target_socket, "->".colorize.green, delay)
      wait.send(nil)
    end
    spawn do
      forward_socket(target_socket, proxy_socket, "<-".colorize.red, delay)
      wait.send(nil)
    end

    2.times { wait.receive }
  end
rescue ex : Socket::ConnectError
  abort(ex.message)
end

def main
  options = parse_options

  Process.on_interrupt do
    Log.info { "Bye" }
    exit
  end

  proxy_server = TCPServer.new(options[:proxy_port])
  Log.info { "Listening port #{options[:proxy_port]} " \
             "and redirecting to #{options[:target_host]}:#{options[:target_port]} " \
             "after #{options[:delay]}ms..." }

  loop do
    if proxy_socket = proxy_server.accept?
      spawn do
        Log.info { "Client connected to proxy" }
        handle_connection(proxy_socket, options[:target_host], options[:target_port], options[:delay])
      end
    end
  end
rescue ex : Socket::BindError | Socket::ConnectError
  abort(ex.message)
end

main
