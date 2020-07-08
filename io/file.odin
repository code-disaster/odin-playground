package io

File :: struct {
    size: u64,
    file_type: File_Type,
    path: string,
}

File_Type :: enum {
    File,
    Directory,
}

Error :: enum {
    None,
    FileNotFound,
}
