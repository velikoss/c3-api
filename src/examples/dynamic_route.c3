module c3test;
import c3api;
import std::collections::map;

// Ignore c3api::Cref self = null, its just backend stuff
fn HttpResponse c3api::ControllerParadise.greetings(c3api::Cref self = null, HttpRequest req, HashMap(<String,String>) args) @Controller("/hi/{username}") {
    @pool() { // Using pool because of dstring::temp_new();
        HttpResponse res;
        res.status = HttpStatus.OK;
        DString greetings = dstring::temp_new();
        greetings.appendf("Hi, %s!\n", args["username"]!!);
        res.body = string::new_format(greetings.tcopy_str(), req.method, req.uri);
        return res;
    };
}