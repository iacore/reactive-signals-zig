Reactive signal library in Zig.

Benchmark code adapted from [maverick-js/signals](https://github.com/maverick-js/signals/pull/19/files#diff-ed2047e0fe1c26b6afee97d3b120cc35ee4bc0203bc06be33687736a16ac4a8e).

## Documentation

Read [src/main.zig](src/main.zig).

## Todo

- add test suite
- add solid.js-like interface

## optimization ideas

The current `BijectMap` is fast enough already.

- cache lookup, so `BijectMap.add` can be used later faster
- coz: tested. not useful.
- ReleaseFast: same speed as ReleaseSafe.
