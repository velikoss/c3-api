module c3api;

import std::collections;
import std::io;

def StringList = List(<String>);
def HttpHeaders = HashMap(<String, StringList>);

fn void HttpHeaders.add_header(HttpHeaders* self, String headerName, String headerValue) {
    if (try entry = self.get_entry(headerName)) {
        entry.value.push(headerValue);
    } else {
        StringList header;
        header.new_init();
        header.push(headerValue);
        self.set(headerName, header);
    }
}

fn void! HttpHeaders.from_lines(HttpHeaders* self, List(<String>) lines) {
    @pool() {
        foreach (line: lines) {
            line = line.trim();
            if (line == "") break;

            usz colon = line.index_of_char(':')!;

            String headerName = line[0..colon].trim();
            String headerValue = line[colon+1..].trim();

            self.add_header(headerName, headerValue);
        }
        lines.free();
    };
}