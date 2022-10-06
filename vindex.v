module main

import os
import vweb
import time
import flag
import sync
import strings

__global config Config

struct Config {
    host string
    port int
    dir string
    timestamp bool
    verbose bool
}

struct Server {
    vweb.Context
}

fn main() {
    mut params := flag.new_flag_parser(os.args)
    params.description("Fast and simple file list server written in V")
    params.skip_executable()

    config = Config {
        dir: params.string("dir", `d`, os.getwd(), "the dir to serve its content, default is ./")
        host: params.string("host", `l`, "127.0.0.1", "the host to listen on, default is 127.0.0.1")
        port: params.int("port", `p`, 3500, "the port to be used for listening, default is 3000")
        timestamp: params.bool("timestamp", `t`, false, "use timestamp in mtime, default is false")
        verbose: params.bool("verbose", `v`, false, "enable verbose mode, default is false")
    }

    params.finalize() or {
        eprintln("error: use `vast --help` to see usage")
        return
    }

    vweb.run_at(&Server{}, vweb.RunParams{
        host: config.host
        port: config.port
        family: .ip
    }) or { panic(err) }
}

[inline]
fn unix_to_gmt(unix_time i64) string {
    fmt_string := 'ddd, DD MMM YYYY kk:mm:ss'
    result := time.unix(unix_time - time.offset()).custom_format(fmt_string)
    return '${result} GMT'
}

fn file_meta(path string, file string) string {
    full_path := path + "/" + file
    is_dir := os.is_dir(full_path)
    munix := os.file_last_mod_unix(file)
    mtime := if config.timestamp {munix.str()} else {'"${unix_to_gmt(munix)}"'}
    return if is_dir {'{"name":"$file","type":"directory","mtime":$mtime}'}
    else {'{"name":"$file","type":"file","mtime":$mtime,"size":${os.file_size(full_path).str()}}'}
}

fn file_list(path string) []string {
    stop_watch := time.new_stopwatch()
    mut files := []string{}
    flist := os.ls(path) or {[]}
    mut wait_group := sync.new_waitgroup()
    for i in 0..flist.len {
        wait_group.add(1)
        go fn (path string, fname string, mut files []string, mut wg sync.WaitGroup) {
            defer { wg.done() }
            files << file_meta(path, fname)
        }(path, flist[i], mut &files, mut wait_group)
    }
    wait_group.wait()
    if config.verbose { println('File list took: ${stop_watch.elapsed().milliseconds()}ms') }
    return files
}

fn file_array_joint(files []string) string {
    initial_size := if _unlikely_(files.len == 0) {0} else { files.len * files[0].len }
    mut files_string := strings.new_builder(initial_size)
    files_string.write_u8(`[`)
    for index in 0..files.len {
        files_string.write_string(files[index])
        if _likely_(index != files.len - 1) { files_string.write_u8(`,`) }
    }
    files_string.write_u8(`]`)
    return files_string.str()
}

['/:path...']
pub fn (mut server Server) app_main(path string) vweb.Result {
    if config.verbose { println('Request: $path') }
    flist := file_list(config.dir + path)
    files := file_array_joint(flist)
    return server.text(files)
}