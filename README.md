# vindex - Fast Indexer written in V

Generate json string for a directory which is compatible with nginx's `autoindex` module. 

## Usage

```bash
$ ./vindex -h
Usage: vindex [options] 

Description: Fast and simple file list server written in V

This application does not expect any arguments

Options:
  -l, --host <string>       host for listening, default is 127.0.0.1
  -p, --port <int>          port for listening, default is 3000
  -d, --dir <string>        base dir of the indexer, default is ./
  -v, --verbose             print info of request, default is false
  -f, --fullpath            print full path when verbose, default is true
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
