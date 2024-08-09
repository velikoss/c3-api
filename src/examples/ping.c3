module c3test;
import c3api;
import std::collections::map;

// Ignore c3api::Cref self = null, its just backend stuff
fn HttpResponse c3api::ControllerParadise.ping(c3api::Cref self = null, HttpRequest req, HashMap(<String,String>) args) @Controller("/ping") {
    HttpResponse res;
    res.status = HttpStatus.OK;
    res.body = string::new_format("Pong!\n", req.method, req.uri);
    return res;
}