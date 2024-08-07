module c3api;

import std::io;
import std::net;
import std::collections;
import std::core::string;
import std::core::dstring;

struct HttpResponse {
    HttpStatus status;
    HttpHeaders headers;
    char[] body;
}

fn void! HttpResponse.write(HttpResponse* self, TcpSocket* socket) {
    DString buffer;
    buffer.new_init(64);

    buffer.appendf("HTTP/1.1 %d %s\r\n", self.status.code, self.status.message);

    Formatter formatter;

    if (self.body.len > 0) {
        if (!self.headers.is_initialized()) {
            self.headers.new_init();
        }

        List(<String>) content_length;
        content_length.new_init(1);
        content_length.push(string::new_format("%d", self.body.len)); // Leaked Allocation

        self.headers.set("Content-Length", content_length);
        content_length.free();
    }

    self.headers.@each(; String key, List(<String>) values)
    {
        foreach (value: values) {
            buffer.appendf("%s: %s\r\n", key, value);
        }
    };

    if (self.headers.len() > 0) {
        buffer.append_chars("\r\n");
    }

    socket.write(buffer.str_view())!;
    buffer.free();

    if (self.body.len > 0) {
        socket.write(self.body)!;
    }
}

fn void HttpResponse.free(HttpResponse* self) {
    self.headers.free();
    free(self.body);
    //free(self);
}
