# vindex - Fast Indexer written in V

Generate json string for a directory which is compatible with nginx's `autoindex` module. 

## Usage

```bash
$ ./vindex -h
Usage: vindex [options] 

Description: Fast and simple file list server written in V

This application does not expect any arguments

Options:
  -p, --port <int>          print info of request, default is false
  -d, --dir <string>        base dir of the indexer, default is ./
  -v, --verbose             print full path when verbose, default is true
  -f, --fullpath            channel size for file metadata, default is 1000
  -h, --help                display this help and exit
  --version                 output version information and exit
```

## Compile

```bash
$ v -prod -skip-unused -cc gcc -cflags "-O3 -static -flto" .
```

## TODO

- [x] Use a faster implementation to replace WaitGroup
- [ ] No GC, complete manual memory management
