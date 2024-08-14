module c3test;
import c3api;
import std::collections::map;

// Ignore c3api::Cref self = null, its just backend stuff
fn HttpResponse c3api::ControllerParadise.file(c3api::Cref self = null, HttpRequest req, HashMap(<String,String>) args)
@Controller("/myconfig") @File("config.json") {
    return {.body = "200"};
}