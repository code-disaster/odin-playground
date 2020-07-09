package io

import "core:fmt"
import "core:strings"
import win32 "core:sys/win32"

OS :: "windows";

PATH_SEPARATOR :: "\\";
PATH_SEPARATOR_CHAR :: '\\';

find_files :: proc(path: string, callback: proc(file: File) -> bool) -> Error {

    search_path := strings.concatenate(
        {path, PATH_SEPARATOR},
        context.temp_allocator
    );

    search_pattern := strings.concatenate(
        {search_path, "*"},
        context.temp_allocator
    );

    ffd: win32.Find_Data_A;

    ffh: win32.Handle = win32.find_first_file_a(
        strings.clone_to_cstring(search_pattern, context.temp_allocator),
        &ffd
    );

    if ffh == win32.INVALID_HANDLE {
        return Error.FileNotFound;
    }

    defer {
        win32.find_close(ffh);
    }

    for {

        file_name_len := len_from_ptr(ffd.file_name[:], len(ffd.file_name));
        file_name := strings.string_from_ptr(&ffd.file_name[0], file_name_len);

        ignore := file_name == "." || file_name == "..";

        if !ignore {

            file := File {
                path = strings.concatenate(
                    {search_path, file_name},
                    context.temp_allocator
                ),
            };

            file.size = u64(ffd.file_size_high) << 32 + u64(ffd.file_size_low);

            file.file_type = (ffd.file_attributes & win32.FILE_ATTRIBUTE_DIRECTORY) != 0
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

        if !win32.find_next_file_a(ffh, &ffd) {
            break;
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
