module main

import os
import vweb
import time
import flag
import sync
import strings
import v.vmod

const (
    app_usage = [
        "base dir of the indexer, default is ./",
        "host for listening, default is 127.0.0.1"
        "port for listening, default is 3000"
        "print info of request, default is false"
        "print full path when verbose, default is true"
    ]
)

struct App {
    vweb.Context
pub:
    config Config [vweb_global]
}

struct Config {
    host string
    port int
    dir string
    verbose bool
    log_full_path bool
}

pub fn main() {
    vm := vmod.decode( @VMOD_FILE ) or { panic(err) }
    mut fp := flag.new_flag_parser(os.args)
    fp.application(vm.name)
    fp.limit_free_args(0, 0)!
    fp.description(vm.description)
    fp.skip_executable()

    // Initialize the global config
    config := Config {
        dir: fp.string("dir", `d`, os.getwd(), app_usage[0])
        host: fp.string("host", `l`, "127.0.0.1", app_usage[1])
        port: fp.int("port", `p`, 3500, app_usage[2])
        verbose: fp.bool("verbose", `v`, false, app_usage[3])
        log_full_path: fp.bool("log_full_path", `f`, true, app_usage[4])
    }

    // Exit when bad flag matched
    fp.finalize() or {
        eprintln("error: use `$vm.name --help` to see usage")
        return
    }

    vweb.run_at(&App{config: &config}, vweb.RunParams{
        host: config.host
        port: config.port
        family: .ip
    }) or { println(err.msg().title()) exit(1) }
}

[inline]
fn print_verbose(verbose bool, msg string) {
    vm := vmod.decode( @VMOD_FILE ) or { panic(err) }
    if verbose { println("[$vm.name] $msg") }
}

fn unix_to_gmt(unix_time i64) string {
    fmt_string := 'ddd, DD MMM YYYY HH:mm:ss'
    timestamp_local := time.unix(unix_time - time.offset())
    return '${timestamp_local.custom_format(fmt_string)} GMT'
}

fn get_file_meta(path string, fname string) string {
    full_path := path + "/" + fname

    // Get the last modified time of the file
    last_mod_unix := os.file_last_mod_unix(full_path)
    last_mod_time := '"${unix_to_gmt(last_mod_unix)}"'

    // If it's not a directory then size is not needed
    return if os.is_dir(full_path) {
        '{"name":"${fname}","type":"directory","mtime":${last_mod_time}}'
    } else {
        file_size := os.file_size(full_path)
        '{"name":"${fname}","type":"file","mtime":${last_mod_time},"size":${file_size}}'
    }
}

fn get_file_list(path string) shared []string {
    shared files := []string{}
    file_list := os.ls(path) or {[]}
    file_meta_ch := chan string{cap: file_list.len}

    // Add jobs to channel
    for i in 0 .. file_list.len {
        go fn (path string, fname string, ch chan string) {
            ch <- get_file_meta(path, fname)
        }(path, file_list[i], file_meta_ch)
    }

    // Retrieve metadata from channel
    for _ in 0 .. file_list.len {
        file_meta := <- file_meta_ch
        lock { files << file_meta }
    }

    return files
}

fn file_array_to_json(files []string) string {
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
    full_path := app.config.dir + path
    log_path := if app.config.log_full_path { full_path } else { path }

    // Return error if it not exists or not a directory
    if !os.exists(full_path) {
        print_verbose(app.config.verbose, 'Path not found: ${log_path}')
        return app.not_found()
    }
    if !os.is_dir(full_path) {
        app.set_status(400, '')
        print_verbose(app.config.verbose, 'Not a directory: ${log_path}')
        return app.text('Not a directory')
    }

    // It's a valid directory
    print_verbose(app.config.verbose, 'Request: ${log_path}')

    // It's a directory, let's list it
    stop_watch := time.new_stopwatch()
    file_list := rlock { get_file_list(full_path) }
    time_elapsed := stop_watch.elapsed().milliseconds()
    print_verbose(app.config.verbose, 'Get file list took: ${time_elapsed}ms')
    print_verbose(app.config.verbose, 'Number of file: ${file_list.len}')

    files_json := file_array_to_json(file_list)

    return app.text(files_json)
}