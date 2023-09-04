module main

import os
import vweb
import time
import flag
import log
import strings
import v.vmod

const app_usage = [
    "base dir of the indexer, default is ./",
    "host for listening, default is 127.0.0.1"
    "port for listening, default is 3000"
    "print full path when verbose, default is true"
]

struct App {
    vweb.Context
    config Config [vweb_global]
}

struct Config {
    host string
    port int
    dir string
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
    }

    if fp.bool("verbose", `v`, false, app_usage[3]) {
    	log.set_level(.debug)
    }

    // Exit when bad flag matched
    fp.finalize() or {
        eprintln("error: use `$vm.name --help` to see usage")
        return
    }

    vweb.run_at(
        &App{
            config: &config
        },
        vweb.RunParams{
            host: config.host
            port: config.port
            family: .ip
        }
    ) or {
        println(err.msg().title())
        exit(1)
    }
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

fn get_file_list(path string) []string {
    file_list := os.ls(path) or {[]}
    mut files := []string{cap: file_list.len}

    // Add jobs to channel
    for i in 0 .. file_list.len {
        files << get_file_meta(path, file_list[i])
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
        '{"name":"${fname}","type":"directory","mtime":"${last_mod_time}"}'
    } else {
        file_size := os.file_size(full_path)
        '{"name":"${fname}","type":"file","mtime":"${last_mod_time}","size":${file_size}}'
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

['/:path...']
pub fn (mut app App) app_main(path string) vweb.Result {
    full_path := app.config.dir + path

    // Return error if it not exists or not a directory
    if !os.exists(full_path) {
        log.warn('Path not found: ${full_path}')
        return app.not_found()
    }
    if !os.is_dir(full_path) {
        app.set_status(400, '')
        log.warn('Not a directory: ${full_path}')
        return app.text('Not a directory')
    }

    // It's a valid directory
    log.info('Request: ${full_path}')

    // It's a directory, let's list it
    stop_watch := time.new_stopwatch()
    file_list := get_file_list(full_path)
    time_elapsed := f64(stop_watch.elapsed().microseconds()) / 1000.0

    // Print the log of file list
    log.debug('Get file list took: ${time_elapsed}ms')
    log.debug('Number of file: ${file_list.len}')

    files_json := file_array_to_json(file_list)
    return app.text(files_json)
}
