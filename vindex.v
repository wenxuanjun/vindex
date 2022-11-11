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

struct App {
    vweb.Context
}

pub fn main() {
    mut fp := flag.new_flag_parser(os.args)

    // Metadata of the application
    fp.application("vindex")
    fp.description("Fast and simple file list server written in V")
    fp.skip_executable()

    // Initialize the global config
    config = Config {
        dir: fp.string("dir", `d`, os.getwd(), "base dir of the indexer, default is ./")
        host: fp.string("host", `l`, "127.0.0.1", "host for listening, default is 127.0.0.1")
        port: fp.int("port", `p`, 3500, "port for listening, default is 3000")
        timestamp: fp.bool("timestamp", `t`, false, "use timestamp, default is false")
        verbose: fp.bool("verbose", `v`, false, "enable verbose, default is false")
    }

    fp.finalize() or {
        eprintln("error: use `vindex --help` to see usage")
        return
    }

    vweb.run_at(&App{}, vweb.RunParams{
        host: config.host
        port: config.port
        family: .ip
    }) or { println(err.msg().title()) exit(1) }
}

[inline]
fn unix_to_gmt(unix_time i64) string {
    fmt_string := 'ddd, DD MMM YYYY HH:mm:ss'
    timestamp_local := time.unix(unix_time - time.offset())
    return '${timestamp_local.custom_format(fmt_string)} GMT'
}

fn file_meta(path string, fname string) string {
    full_path := path + "/" + fname

    mod_unix := os.file_last_mod_unix(full_path)
    mod_time := if config.timestamp {
        mod_unix.str()
    } else {
        '"${unix_to_gmt(mod_unix)}"'
    }

    // If it's not a directory then size is not needed
    return if os.is_dir(full_path) {
        '{"name":"${fname}","type":"directory","mtime":${mod_time}}'
    } else {
        file_size := os.file_size(full_path).str()
        '{"name":"${fname}","type":"file","mtime":${mod_time},"size":${file_size}}'
    }
}

fn file_list(path string) shared []string {
    stop_watch := time.new_stopwatch()

    shared files := []string{}
    flist := os.ls(path) or {[]}
    mut wait_group := sync.new_waitgroup()
    // mut sema := sync.new_semaphore()

    // Add jobs to wait group
    for i in 0 .. flist.len {
        wait_group.add(1)
        go fn (path string, fname string, shared files []string, mut wg &sync.WaitGroup) {
            // println('Processing ${fname}')
            // sema.post()
            lock { files << file_meta(path, fname) }
            // sema.try_wait()
            // println('Done ${fname}')
            defer { wg.done() }
        }(path, flist[i], shared files, mut wait_group)
    }

    // Wait for all go routines to finish
    wait_group.wait()
    //sema.try_wait()

    if config.verbose {
        println('File list took: ${stop_watch.elapsed().milliseconds()}ms')
    }

    // return files
    return files
}

fn file_array_joint(files []string) string {
    // Initial size for better performance
    mut files_string := strings.new_builder(
        if _likely_(files.len > 0) {
            files.len * files[0].len
        } else { 0 }
    )

    files_string.write_u8(`[`)

    // Write the files to the string
    for index in 0 .. files.len {
        files_string.write_string(files[index])
        if _likely_(index != files.len - 1) {
            files_string.write_u8(`,`)
        }
    }

    files_string.write_u8(`]`)

    return files_string.str()
}

['/:path...']
pub fn (mut app App) app_main(path string) vweb.Result {
    if config.verbose {
        println('Request: ${path}')
    }

    // Return error if it not exists or not a directory
    if !os.exists(config.dir + path) {
        return app.not_found()
    }
    if !os.is_dir(config.dir + path) {
        app.set_status(400, '')
        return app.text('Not a directory')
    }

    // It's a directory, let's list it
    flist := rlock { file_list(config.dir + path) }
    files := file_array_joint(flist)

    return app.text(files)
}