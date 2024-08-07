module c3api;

import std::collections;

def StringList = List(<String>);
def HttpHeaders = HashMap(<String, StringList>);

fn void! HttpHeaders.from_lines(HttpHeaders* self, List(<String>) lines) {
    @pool() {
        foreach (line: lines) {
            line = line.trim();
            if (line == "") break;

            usz colon = line.index_of_char(':')!;

            String headerName = line[0..colon].trim();
            String headerValue = line[colon+1..].trim();

            if (try entry = self.get_entry(headerName)) {
              entry.value.push(headerValue);
            } else {
              List(<String>) values;
              values.temp_init(2);
              values.push(headerValue);
              self.set(headerName, values);
            }
        }
        lines.free();
    };
}
