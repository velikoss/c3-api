module c3api::config;

import std::io;
import std::io::os;
import std::io::file;
import std::collections::object;
import std::encoding::json;

struct Config {
    String address;
    uint port;
}

fn Config readFromFile() {
    @pool() {
        DString _filename = dstring::temp_new();
        _filename.appendf("%s\\config.json", os::getcwd()!!);
        String filename = _filename.tcopy_str();


        if (!file::is_file(filename)) {
            io::printn("No file(");
            File! file = file::open(filename, "w");
            if (catch anyfault err = file) {
                io::printn(err);
                return {};
            }
            file.write(
`{
    "address": "127.0.0.1",
    "port": 8080
}`)!!;
            file.flush()!!;
        }
        File! file = file::open(filename, "r");
        Object*! json = json::parse(&file);
        file.flush()!!;
        Config config = {.address = json.get_string("address")??"", .port = json.get_int("port")??0};
        free(json)!!;
        return config;
    };
}