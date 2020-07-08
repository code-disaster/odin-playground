package main

import "core:fmt"
import "core:strings"
import "core:os"

import "io"

main :: proc() {

    cwd := os.get_current_directory();


    callback :: proc(file: io.File) -> bool {

        if strings.has_suffix(file.path, ".git") && file.file_type == io.File_Type.Directory {
            return false;
        }

        fmt.println("   ", file.path);

        return true;
    }

    err := io.find_files(cwd, callback);

    if err != io.Error.None {
        fmt.println("I/O Error:", err);
        return;
    }

    fmt.println("\nOk.");
}
