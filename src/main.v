module main

import os
import time
import flag
import sync
import strings
import v.vmod
import picoev
import picohttpparser

const app_usage = [
    "base dir of the indexer, default is ./",
    "port for listening, default is 3000"
    "print info of request, default is false"
    "print full path when verbose, default is true"
    "channel size for file metadata, default is 1000"
]

struct Config {
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
        port: fp.int("port", `p`, 3500, app_usage[2])
        verbose: fp.bool("verbose", `v`, false, app_usage[3])
        log_full_path: fp.bool("fullpath", `f`, true, app_usage[4])
    }

    // Exit when bad flag matched
    fp.finalize() or {
        eprintln("error: use `$vm.name --help` to see usage")
        return
    }

	// Start the server
	println("[$vm.name] Listening on 0.0.0.0:${config.port}")

    picoev.new(port: config.port, cb: &app_handler, user_data: &config).serve()
}

[inline]
fn print_verbose(verbose bool, msg string) {
    vm := vmod.decode( @VMOD_FILE ) or { panic(err) }
    if verbose { println("[$vm.name] $msg") }
}

fn app_handler(mut config Config, req picohttpparser.Request, mut res picohttpparser.Response) {
    full_path := config.dir + req.path
    log_path := if config.log_full_path { full_path } else { req.path }

    // Return error if it not exists or not a directory
    if !os.exists(full_path) {
        print_verbose(config.verbose, 'Path not found: ${log_path}')
        res.http_404() res.end()
        return
    }
    if !os.is_dir(full_path) {
        print_verbose(config.verbose, 'Not a directory: ${log_path}')
        res.http_405() res.end()
        return
    }

    // It's a valid directory
    print_verbose(config.verbose, 'Request: ${log_path}')

    // It's a directory, let's list it
    stop_watch := time.new_stopwatch()
    file_list := rlock { get_file_list(full_path) }
    time_elapsed := stop_watch.elapsed().milliseconds()

    // Print the log of file list
    print_verbose(config.verbose, 'Get file list took: ${time_elapsed}ms')
    print_verbose(config.verbose, 'Number of file: ${file_list.len}')

    files_json := file_array_to_json(file_list)

    // Write the response
    res.http_ok() res.header_server() res.header_date()
    res.plain() res.body(files_json) res.end()
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
        lock { files << <- file_meta_ch }
    }

    return files
}

fn get_file_meta(path string, fname string) string {
    full_path := path + "/" + fname

    // Get the last modified time of the file
    last_mod_unix := os.file_last_mod_unix(full_path)
    last_mod_time := unix_to_gmt(last_mod_unix)

    // If it's not a directory then size is not needed
    return if os.is_dir(full_path) {
        '{"name":"${fname}","type":"directory","mtime":${last_mod_time}}'
    } else {
        file_size := os.file_size(full_path)
        '{"name":"${fname}","type":"file","mtime":${last_mod_time},"size":${file_size}}'
    }
}

fn unix_to_gmt(unix_time i64) string {
    // For our format, it is always 29 bytes
    mut mtime_string := strings.new_builder(29)

    timestamp_local := time.unix(unix_time - time.offset())
    week_index := timestamp_local.day_of_week()
    week_string := time.days_string[(week_index - 1) * 3 .. week_index * 3]
    month_index := timestamp_local.month
    month_string := time.months_string[(month_index - 1) * 3 .. month_index * 3]

    mtime_string.write_string(week_string)
    mtime_string.write_string(', ')
    mtime_string.write_u8(timestamp_local.day / 10 + `0`)
    mtime_string.write_u8(timestamp_local.day % 10 + `0`)
    mtime_string.write_u8(` `)
    mtime_string.write_string(month_string)
    mtime_string.write_u8(` `)
    mtime_string.write_string(timestamp_local.year.str())
    mtime_string.write_u8(` `)
    mtime_string.write_u8(timestamp_local.hour / 10 + `0`)
    mtime_string.write_u8(timestamp_local.hour % 10 + `0`)
    mtime_string.write_u8(`:`)
    mtime_string.write_u8(timestamp_local.minute / 10 + `0`)
    mtime_string.write_u8(timestamp_local.minute % 10 + `0`)
    mtime_string.write_u8(`:`)
    mtime_string.write_u8(timestamp_local.second / 10 + `0`)
    mtime_string.write_u8(timestamp_local.second % 10 + `0`)
    mtime_string.write_string(" GMT")
    return mtime_string.str()
}
