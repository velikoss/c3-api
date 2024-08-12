module c3api;

import std::io;
import std::net;
import std::collections;
import std::core::string;

const ulong MAX_READ_SIZE = /* 5 MiB */ 1024 * 1024 * 5;

struct HttpRequest {
    HttpVerb method;
    String uri;
    HttpHeaders headers;
    char[] body;
}

fault HttpRequestError {
    NO_DATA,
    REQUEST_TOO_LARGE,
    MALFORMED_REQUEST,
    UNSUPPORTED_VERSION,
    UNIMPLEMENTED
}

fault HttpVerbError {
    INVALID_VERB
}

fn void! HttpRequest.set_method(HttpRequest* self, String verb) {
    self.method = {|
        switch (verb) {
            case "HEAD": return HttpVerb.HEAD;
            case "GET": return HttpVerb.GET;
            case "PATCH": return HttpVerb.PATCH;
            case "POST": return HttpVerb.POST;
            case "PUT": return HttpVerb.PUT;
            case "DELETE": return HttpVerb.DELETE;
            case "OPTIONS": return HttpVerb.OPTIONS;
            case "TRACE": return HttpVerb.TRACE;
            case "CONNECT": return HttpVerb.CONNECT;
            default: return HttpVerbError.INVALID_VERB?;
        }
    |}!;
}


fn void! HttpRequest.read(HttpRequest* self, TcpSocket* socket) {
    @pool() {
        List(<char>) bytes;
        bytes.new_init(256);

        char[256] buffer;
        while (try usz bytes_read = socket.read(&buffer)) {
            bytes.add_array(buffer[:bytes_read]);

            if (bytes.size >= MAX_READ_SIZE) return HttpRequestError.REQUEST_TOO_LARGE?;
            if (bytes_read < 256) break;
        }

        if (bytes.size == 0) return HttpRequestError.NO_DATA?;

        List(<char>) header;
        header.new_init(256);

        usz i = 0;
        for (; i < bytes.size; i++) {
            if (
                bytes[i] == '\r' && bytes[i + 1] == '\n' &&
                bytes[i + 2] == '\r' && bytes[i + 3] == '\n'
            ) {
                i += 4;
                break;
            }

            header.push(bytes[i]);
        }
        header.push('\0');

        char[] body = bytes.entries[i..bytes.size];

        StringList header_lines;
        header_lines.new_init_with_array(((ZString)header.entries).str_view().tsplit("\r\n"));

        String[] status_line = header_lines.pop_first()!.tsplit(" ");
        if (status_line.len != 3) return HttpRequestError.MALFORMED_REQUEST?;

        String version = status_line[2];
        if (version != "HTTP/1.1") return HttpRequestError.UNSUPPORTED_VERSION?;

        self.set_method(status_line[0])!;
        self.uri = status_line[1];

        self.headers.new_init();
        self.headers.from_lines(header_lines)!;
        self.body = body;

        header.free();
    };
}

fn void HttpRequest.free(HttpRequest* self) {
    self.headers.free();
}

