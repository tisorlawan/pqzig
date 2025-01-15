# Typesafe PostgreSQL Zig Connector

A lightweight PostgreSQL database connector written in Zig, designed with a focus on type safety and simplicity. This project provides a simple interface for interacting with PostgreSQL databases while leveraging Zig's compile-time features.

## Features

- Type-safe database operations
- Support for common PostgreSQL data types
- Built-in connection pooling
- Thread-safe logging system
- Structured error handling

## Dependencies

- Zig (latest version)
- libpq
- pkg-config (for development)

## Getting Started

### Prerequisites

Make sure you have PostgreSQL and its development libraries installed on your system.

### Building

```bash
zig build
```

### Running

```bash
zig build run
```

### Testing

```bash
zig build test
```

## References:

- [posgres](https://www.postgresql.org/docs/current/libpq-exec.html#LIBPQ-EXEC-SELECT-INFO)
