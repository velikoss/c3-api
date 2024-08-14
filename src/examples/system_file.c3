module c3test;
import c3api;
import std::collections::map;

// Ignore c3api::Cref self = null, its just backend stuff
fn HttpResponse c3api::ControllerParadise.winlogo(c3api::Cref self = null, HttpRequest req, HashMap(<String,String>) args)
@Controller("/windows/icon") @File("C:/Windows/System32/@WLOGO_96x96.png") {
    return {.body = "200"};
}