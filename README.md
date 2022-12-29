# vindex - Fast Indexer written in V

Generate json string for a directory which is compatible with nginx's `autoindex` module. 

## Usage

```bash
$ ./vindex -h
Usage: vindex [options] [ARGS]

Description: Fast and simple file list server written in V

Options:
  -l, --host <string>       host for listening, default is 127.0.0.1
  -p, --port <int>          port for listening, default is 3000
  -d, --dir <string>        base dir of the indexer, default is ./
  -t, --timestamp           use timestamp, default is false
  -v, --verbose             enable verbose, default is false
  -h, --help                display this help and exit
  --version                 output version information and exit
```

## Compile

```bash
$ v -enable-globals -prod -cc clang -cflags "-Ofast -static -flto" vindex.v
```

## TODO

- [x] Use a faster implementation to replace WaitGroup
- [ ] No GC, complete manual memory management