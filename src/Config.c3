module c3api::config;

import std::io;
import std::io::os;
import std::io::file;
import std::io::path;
import std::collections::object;
import std::encoding::json;

struct Config {
    String address;
    uint port;
    bool cors;
}

fn Config readFromFile() {
    @pool() {
        Path path = path::tgetcwd()!!;
        path = path.append("config.json")!!;

        if (!path::is_file(path)) {
            io::printn("No file(");
            File! file = file::open_path(path, "w");
            if (catch anyfault err = file) {
                io::printn(err);
                return {};
            }
            file.write(
`{
    "address": "127.0.0.1",
    "port": 8080,
    "enable-cors": false
}`)!!;
            file.flush()!!;
            file.close()!!;
        }

        File! file = file::open_path(path, "r");
        Object*! json = json::parse(&file);
        file.flush()!!;
        file.close()!!;

        Config config = {.address = json.get_string("address")??"", .port = json.get_int("port")??0, .cors = json.get_bool("enable-cors")??false};

        free(json)!!;
        return config;
    };
}