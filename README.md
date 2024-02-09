# 🦥️ delay-proxy

A TCP proxy that adds a configurable amount of delay.

A simple way to simulate services behind slow networks locally.

## Installation

Compile it and manually install, it's just a single executable.

First install the [crystal language compiler](https://crystal-lang.org/install/), then:

```
git clone github.com/hugopl/delay-proxy.git
cd delay-proxy
crystal build --release src/main.cr
```

Then copy `bin/delay-proxy` to whatever you want, e.g. `/usr/bin/`.


## Usage 🖥️↔️🦥️↔️💻️

Suppose you want to simulate a redis-server behind a slow connection:

Start the redis-server in some terminal.

```
redis-server
```

Now start the delay-proxy

```
delay-proxy :6379
```

It will open the port 1234 and redirect all data to port 6369 with a delay of 200±10%ms

Now open redis-cli in yet another terminal

```
redis-cli -p 1234
```

All commands should work, but with a delay in the response.
```
127.0.0.1:1234> ping
PONG
127.0.0.1:1234>
```

On delay-proxy terminal you see
```
Listening port 1234 and redirecting to localhost:6379 after 200ms...
Client connected to proxy
Proxy connected to target
-> 27 bytes ⌛213ms
<- 49920 bytes ⌛205ms
<- 116160 bytes ⌛195ms
<- 39125 bytes ⌛201ms
-> 14 bytes ⌛215ms
<- 7 bytes ⌛193ms
```

The complete command without using the defaults is:

```
delay-proxy localhost:6379 1234 200
```

## Development

Suggestions, open an issue.

## Contributing

1. Fork it (<https://github.com/hugopl/delay-proxy/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Hugo Parente Lima](https://github.com/hugopl) - creator and maintainer
