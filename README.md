# Protobuf Benchmarks by Zserio

[![](https://github.com/ndsev/zserio-protobuf-benchmarks/actions/workflows/build_linux.yml/badge.svg)](https://github.com/ndsev/zserio-protobuf-benchmarks/actions/workflows/build_linux.yml)
[![](https://github.com/ndsev/zserio-protobuf-benchmarks/actions/workflows/build_windows.yml/badge.svg)](https://github.com/ndsev/zserio-protobuf-benchmarks/actions/workflows/build_windows.yml)
[![](https://img.shields.io/github/watchers/ndsev/zserio-protobuf-benchmarks.svg)](https://GitHub.com/ndsev/zserio-protobuf-benchmarks/watchers)
[![](https://img.shields.io/github/forks/ndsev/zserio-protobuf-benchmarks.svg)](https://GitHub.com/ndsev/zserio-protobuf-benchmarks/network/members)
[![](https://img.shields.io/github/stars/ndsev/zserio-protobuf-benchmarks.svg?color=yellow)](https://GitHub.com/ndsev/zserio-protobuf-benchmarks/stargazers)

--------

Protobuf Benchmarks by Zserio is an independent benchmark which uses
[zserio-datasets](https://github.com/ndsev/zserio-datasets) to compare Google's
[Protocol Buffers](https://github.com/protocolbuffers/protobuf) performance to [Zserio](http://zserio.org/)
on the same sets of data.

## Zserio vs. Protocol Buffers

Google's Protocol Buffers are very popular and in wide-spread use. One of the many questions we always have to
answer is: "Why don't you use Protobuf? It is already there."

Fact is that it wasn't open sourced when we would have needed it. Maybe we would have used it back then. But
even today we think we came along with something more tailored to our needs. This is also the reason why we
open sourced Zserio after such a long time.

So let's see how Zserio performs in comparison to Protobuf. For being fair we have chosen as well the example
that is used on Google's documentation page of Protobuf (`addressbook`). This example does not really help
to promote a binary - thus smaller - representation of data. It mostly uses strings.

## Running

Make sure you have the following pre-requisites installed:

- Protocol Buffers Compiler
- CMake
- ZIP utility
- Supported Compiler (gcc, clang, mingw, msvc)

Also do not forget to fetch the datasets with `git submodule update --init`.

Now you are ready to run the `benchmark.sh` script which accepts the required platform as a parameter 
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
[apollo.proto]: https://github.com/ndsev/zserio-protobuf-benchmarks/blob/master/benchmarks/apollo/apollo.proto
[carsales.proto]: https://github.com/ndsev/zserio-protobuf-benchmarks/blob/master/benchmarks/carsales/carsales.proto
[simpletrace.proto]: https://github.com/ndsev/zserio-protobuf-benchmarks/blob/master/benchmarks/simpletrace/simpletrace.proto

[addressbook.json]: https://github.com/ndsev/zserio-datasets/blob/master/addressbook/addressbook.json
[apollo.proto.json]: https://github.com/ndsev/zserio-datasets/blob/master/apollo/apollo.proto.json
[carsales.json]: https://github.com/ndsev/zserio-datasets/blob/master/carsales/carsales.json
[prague-groebenzell.json]: https://github.com/ndsev/zserio-datasets/blob/master/simpletrace/prague-groebenzell.json

| Benchmark            | Dataset                   | Target               |      Time | Blob Size | Zip Size |
| -------------------- | ------------------------- | -------------------- | --------- | --------- | -------- |
| [addressbook.proto]  | [addressbook.json]        | C++ (linux64-gcc)    |   1.731ms | 356.292kB |    193kB |
| [apollo.proto]       | [apollo.proto.json]       | C++ (linux64-gcc)    |   0.641ms | 286.863kB |    136kB |
| [carsales.proto]     | [carsales.json]           | C++ (linux64-gcc)    |   2.053ms | 399.779kB |    242kB |
| [simpletrace.proto]  | [prague-groebenzell.json] | C++ (linux64-gcc)    |   0.386ms | 113.152kB |     54kB |

### Zserio 2.10

[addressbook.zs]: https://github.com/ndsev/zserio/blob/master/benchmarks/addressbook/addressbook.zs
[addressbook_align.zs]: https://github.com/ndsev/zserio/blob/master/benchmarks/addressbook/addressbook_align.zs
[apollo.zs]: https://github.com/ndsev/zserio/blob/master/benchmarks/apollo/apollo.zs
[apollo.zs.json]: https://github.com/ndsev/zserio-datasets/blob/master/apollo/apollo.zs.json
[carsales.zs]: https://github.com/ndsev/zserio/blob/master/benchmarks/carsales/carsales.zs
[carsales_align.zs]: https://github.com/ndsev/zserio/blob/master/benchmarks/carsales/carsales_align.zs
[simpletrace.zs]: https://github.com/ndsev/zserio/blob/master/benchmarks/simpletrace/simpletrace.zs

| Benchmark              | Dataset                   | Target              |      Time | Blob Size | Zip Size |
| ---------------------- | ------------------------- | ------------------- | --------- | --------- | -------- |
| [addressbook.zs]       | [addressbook.json]        | C++ (linux64-gcc)   |   1.478ms | 305.838kB |    222kB |
| [addressbook_align.zs] | [addressbook.json]        | C++ (linux64-gcc)   |   0.844ms | 311.424kB |    177kB |
| [apollo.zs]            | [apollo.zs.json]          | C++ (linux64-gcc)   |   0.244ms | 226.507kB |    144kB |
| [carsales.zs]          | [carsales.json]           | C++ (linux64-gcc)   |   1.374ms | 280.340kB |    259kB |
| [carsales_align.zs]    | [carsales.json]           | C++ (linux64-gcc)   |   0.925ms | 295.965kB |    205kB |
| [simpletrace.zs]       | [prague-groebenzell.json] | C++ (linux64-gcc)   |   0.221ms |  87.042kB |     66kB |

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
