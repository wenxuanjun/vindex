# vindex - Fast Indexer written in V

Generate json string for a directory which is compatible with nginx's `autoindex` module. 

## Usage

```bash
$ ./vindex -h
Usage:  [options] [ARGS]

Description: Fast and simple file list server written in V

Options:
  -l, --host <string>       the host to listen on, default is 127.0.0.1
  -p, --port <int>          the port to be used for listening, default is 3000
  -d, --dir <string>        the dir to serve its content, default is ./
  -v, --verbose             enable verbose mode, default is false
  -h, --help                display this help and exit
  --version                 output version information and exit
```

## Compile

```bash
$ v -prod -enable-globals -cc gcc vindex.v
```