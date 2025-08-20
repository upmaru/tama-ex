# Tama

An Elixir HTTP client wrapper that provides structured response handling and schema parsing support. Built on top of the Req HTTP client, Tama simplifies API interactions by offering consistent error handling and automatic data parsing using Ecto-style schemas.

## Features

- Simple HTTP client creation with base URL configuration
- Structured response handling with consistent error patterns
- Support for schema-based data parsing
- Built-in error handling for common HTTP status codes (404, 422, 4xx, 5xx)
- Support for both 200 and 201 success responses

## Installation

The package can be installed by adding `tama` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tama, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/tama_ex>.
