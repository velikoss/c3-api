module c3test;
import c3api;
import std::collections::map;

// Ignore c3api::Cref self = null, its just backend stuff
fn HttpResponse c3api::ControllerParadise.src(c3api::Cref self = null, HttpRequest req, HashMap(<String,String>) args)
@Controller("/src") @Folder(".") { // Executable folder
    return {.body = "200"};
}

fn HttpResponse c3api::ControllerParadise.srcfile(c3api::Cref self = null, HttpRequest req, HashMap(<String,String>) args)
@Controller("/src/{file}") @File("./{file}") { // It also can be dynamic!
    return {.body = "200"};
}