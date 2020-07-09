package io

foreign import libc "system:c"

import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"

OS :: "linux";

PATH_SEPARATOR      :: "/";
PATH_SEPARATOR_CHAR :: '/';

_dirent :: struct {
    d_ino           : u64,
    d_off           : i64,
    d_reclen        : u16,
    d_type          : u8,
    d_name          : [256]byte,
}

foreign libc {
    @(link_name="opendir")      _unix_opendir       :: proc(path: cstring) -> rawptr ---;
    @(link_name="closedir")     _unix_closedir      :: proc(dir: rawptr) -> c.int ---;
    @(link_name="readdir")      _unix_readdir       :: proc(dir: rawptr) -> ^_dirent ---;
}

find_files :: proc(path: string, callback: proc(file: File) -> bool) -> Error {

    dir := _unix_opendir(strings.clone_to_cstring(path, context.temp_allocator));

    if dir == rawptr(uintptr(0)) {
        return Error.FileNotFound;
    }

    defer {
        _unix_closedir(dir);
    }

    for {

        entry := _unix_readdir(dir);

        if entry == rawptr(uintptr(0)) {
            break;
        }

        file_name_len := len_from_ptr(entry.d_name[:], len(entry.d_name));
        file_name := strings.string_from_ptr(&entry.d_name[0], file_name_len);

        ignore := file_name == "." || file_name == "..";

        if !ignore {

            file := File {
                path = strings.concatenate(
                    {path, PATH_SEPARATOR, file_name},
                    context.temp_allocator
                ),
            };

            stat, err := os.stat(file.path);

            if err != os.ERROR_NONE {
                return Error.FileNotFound;
            }

            file.size = u64(stat.size);

            file.file_type = os.S_ISDIR(stat.mode)
                ? File_Type.Directory
                : File_Type.File;

            cont := callback(file);

            if file.file_type == File_Type.Directory {

                if cont {

                    sub_path := strings.concatenate(
                        {path, PATH_SEPARATOR, file_name},
                        context.temp_allocator
                    );

                    err := find_files(sub_path, callback);

                    if err != Error.None {
                        return err;
                    }
                }

            } else if !cont {
                break;
            }
        }
    }

    return Error.None;
}

len_from_ptr :: proc(ptr: []byte, len: int) -> int {
    n := 0;
    for ; n < len && ptr[n] != 0; n += 1 {
        // search for zero terminator
    }
    return n;
}
