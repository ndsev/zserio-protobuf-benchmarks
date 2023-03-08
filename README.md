# Protobuf Benchmarks by Zserio

[![](https://github.com/ndsev/zserio-protobuf-benchmarks/actions/workflows/linux.yml/badge.svg)](https://github.com/ndsev/zserio-protobuf-benchmarks/actions/workflows/linux.yml)
[![](https://github.com/ndsev/zserio-protobuf-benchmarks/actions/workflows/windows.yml/badge.svg)](https://github.com/ndsev/zserio-protobuf-benchmarks/actions/workflows/windows.yml)
[![](https://img.shields.io/github/watchers/ndsev/zserio-protobuf-benchmarks.svg)](https://GitHub.com/ndsev/zserio-protobuf-benchmarks/watchers)
[![](https://img.shields.io/github/forks/ndsev/zserio-protobuf-benchmarks.svg)](https://GitHub.com/ndsev/zserio-protobuf-benchmarks/network/members)
[![](https://img.shields.io/github/stars/ndsev/zserio-protobuf-benchmarks.svg?color=yellow)](https://GitHub.com/ndsev/zserio-protobuf-benchmarks/stargazers)

--------

Protobuf Benchmarks by Zserio is an independet benchmark which uses
[zserio-datasets](https://github.com/ndsev/zserio-datasets) to compare Google's
[Protocol Buffers](https://github.com/protocolbuffers/protobuf) performance to [Zserio](http://zserio.org/)
on the same sets of data.

## Running

Running can be done by provided `benchmark.sh` script which accepts as a parameter required platform
(e.g. `cpp-linux64-gcc`):

```
scripts/benchmark.sh <PLATFORM>
```

The script `benchmark.sh` automatically generates simple performance test for each benchmark.
The performance test uses generated Protocol Buffers' API to read appropriate dataset from JSON format,
serialize it into the Protocol Buffers' binary format and then read it again. Both reading time and the BLOB
size are reported. BLOB size after zip compression is reported as well.

## Results

- Used platform: 64-bit Linux Mint 21.1, Intel(R) Core(TM) i7-9850H CPU @ 2.60GHz
- Used compiler: gcc 11.3.0

### Protobuf 3.21.12

[addressbook.proto]: https://github.com/ndsev/zserio-protobuf-benchmarks/blob/master/benchmarks/addressbook/addressbook.proto
[carsales.proto]: https://github.com/ndsev/zserio-protobuf-benchmarks/blob/master/benchmarks/carsales/carsales.proto

[addressbook.json]: https://github.com/ndsev/zserio-datasets/blob/master/addressbook/addressbook.json
[carsales.json]: https://github.com/ndsev/zserio-datasets/blob/master/carsales/carsales.json

| Benchmark              | Dataset                | Target                 |      Time | Blob Size | Zip Size |
| ---------------------- | ---------------------- | ---------------------- | --------- | --------- | -------- |
| [addressbook.proto]    | [addressbook.json]     | C++ (linux64-gcc)      |   1.757ms | 356.292kB |    193kB |
| [carsales.proto]       | [carsales.json]        | C++ (linux64-gcc)      |   2.033ms | 399.779kB |    242kB |

### Zserio 2.10

[addressbook.zs]: https://github.com/ndsev/zserio/blob/master/benchmarks/addressbook/addressbook.zs
[addressbook_align.zs]: https://github.com/ndsev/zserio/blob/master/benchmarks/addressbook/addressbook_align.zs
[carsales.zs]: https://github.com/ndsev/zserio/blob/master/benchmarks/carsales/carsales.zs
[carsales_align.zs]: https://github.com/ndsev/zserio/blob/master/benchmarks/carsales/carsales_align.zs

| Benchmark              | Dataset                | Target                 |      Time | Blob Size | Zip Size |
| ---------------------- | ---------------------- | ---------------------- | --------- | --------- | -------- |
| [addressbook.zs]       | [addressbook.json]     | C++ (linux64-gcc)      |   1.444ms | 305.838kB |    222kB |
| [addressbook_align.zs] | [addressbook.json]     | C++ (linux64-gcc)      |   0.802ms | 311.424kB |    177kB |
| [carsales.zs]          | [carsales.json]        | C++ (linux64-gcc)      |   1.453ms | 280.340kB |    259kB |
| [carsales_align.zs]    | [carsales.json]        | C++ (linux64-gcc)      |   0.823ms | 295.965kB |    205kB |

### Time Comparison

![time comparison](images/ZserioProtobufTimeComparison.png)

### Size Comparison

![size comparison](images/ZserioProtobufSizeComparison.png)

### How to Add New Benchmark

- Add new dataset (e.g. `new_benchmark`) in JSON format
  into [datasets repository](https://github.com/ndsev/zserio-datasets)
- Add new schema (e.g. `new_benchmark`) in Protobuf format into
  [benchmarks directory](https://github.com/ndsev/zserio-protobuf-benchmarks/tree/master/benchmarks)
- Make sure that the first message in the schema file is the top level message
