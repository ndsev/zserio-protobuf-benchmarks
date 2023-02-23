# Protobuf Benchmark by Zserio

Protobuf Benchmark by Zserio is an independet benchmark which is using
[zserio-datasets](https://github.com/ndsev/zserio-datasets) to compare performace of Google's
[Protocol Buffers](https://github.com/protocolbuffers/protobuf) with [Zserio](http://zserio.org/) on the same
sets of data.

The main script `benchmark.sh` automatically generates simple perfromance test for each benchmark.
The performance test uses generated Protocol Buffers' API to read appropriate dataset from JSON fromat,
serialize it into the Protocol Buffers' binary format and then read it again. Both reading time and the BLOB
size are rerpoted.
