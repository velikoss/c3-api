module c3api;
import std::collections::map;

//def RouteFunction = fn HttpResponse(HttpRequest, HashMap(<String,String>));
def RouteFunction = fn HttpResponse(ControllerParadise*, HttpRequest, HashMap(<String,String>));
def RouteMap = HashMap(<String, RouteNode*>);

struct RouteNode {
    String name;
    RouteMap subnodes;
    RouteFunction apply;
}

RouteMap _lowLevel;

fn HttpResponse e404(ControllerParadise* controller = null, HttpRequest req, HashMap(<String,String>) args) {
    HttpResponse res;
    res.status = HttpStatus.NOT_FOUND;
    res.body = string::new_format(`{"type":"error","status":404}` "\n", req.method, req.uri);
    return res;
}

fn RouteNode*! get_next_node(RouteNode* from, String to) {
    return from.subnodes[to] ?? from.subnodes["{}"];
}

import std::io;
import std::core::builtin;

fn RouteFunction get_route(String uri, HashMap(<String,String>)* args) {
    if (uri == "" || uri == "/") {
        return _lowLevel[uri].apply ?? &e404;
    }

    if (uri[0] == '/' && uri.len > 1) uri = uri[1..];

    if (
        !(@ok(uri.index_of_char('{')) && @ok(uri.index_of_char('}'))) // Dynamic URI check
        && _lowLevel.has_key(uri)
    ) {
        return _lowLevel[uri].apply!!;
    }

    String[] nodes = uri.tsplit("/");

    RouteNode*! temp = _lowLevel[nodes[0]];
    if (catch err = temp) {
        if (err != SearchResult.MISSING) io::printfn("Catch err: %s", err);
        return &e404;
    }

    int i = 0;
    while (temp != null && i < nodes.len - 1) {
        temp = get_next_node(temp, nodes[i++])!!;
        if (temp.name[0] == '{' && temp.name[^1] == '}'
        ) (*args)[temp.name[1:^2]] = nodes[i]; // Leaked Allocation
    }

    if (temp == null) return &e404;

    RouteFunction res = temp.apply;
    return res;
}

macro RouteNode* new_route(String name, HashMap(<String, RouteNode*>) subnodes = {}, RouteFunction apply = null) {
    return @clone(RouteNode {.name = name, .subnodes = subnodes, .apply = apply});
}

fn bool String.is_braced(self) {
    return self[0] == '{' && self[^1] == '}';
}

fn void add_route(String route, RouteFunction apply) {
    if (route[0] == '/' && route.len > 1) route = route[1:route.len-1];

    if (
            !(@ok(route.index_of_char('{')) && @ok(route.index_of_char('}'))) // Dynamic URI check
    ) {
        _lowLevel[route] = new_route(.name = route, .apply = apply);
        return;
    }

    String[] nodes = route.split("/");
    RouteNode* temp;

    if (!_lowLevel.has_key(nodes[0])) {
        temp = new_route(nodes[0]);
        _lowLevel[nodes[0]] = temp;
    } else {
        temp = _lowLevel[nodes[0]]!!;
    }

    foreach (i, node : nodes[..^2]) {
        if (try _temp = get_next_node(temp, node)) {
            temp = _temp;
            continue;
        }
        String key = nodes[i + 1].is_braced() ? "{}" : nodes[i + 1];
        temp.subnodes[key] = temp = new_route(nodes[i + 1]);
    }

    temp.apply = apply;
}