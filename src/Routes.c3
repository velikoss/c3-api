module c3api;
import std::collections::map;

def RouteFunction = fn HttpResponse(HttpRequest, HashMap(<String,String>));
def RouteMap = HashMap(<String, RouteNode*>);

struct RouteNode {
    String name;
    RouteMap subnodes;
    RouteFunction apply;
}

RouteMap _lowLevel;

fn HttpResponse e404(HttpRequest req, HashMap(<String,String>) args) {
    HttpResponse res;
    res.status = HttpStatus.NOT_FOUND;
    res.body = string::new_format(`{"type":"error","status":404}` "\n", req.method, req.uri);
    return res;
}

fn RouteNode*! get_next_node(RouteNode* from, String to) {
    return from.subnodes[to] ?? from.subnodes["{}"];
}

import std::io;

fn RouteFunction get_route(String uri, HashMap(<String,String>)* args) {
    if (uri[0] == '/') uri = uri[1..];

    if (
        !(@ok(uri.index_of_char('{')) && @ok(uri.index_of_char('}'))) // Dynamic URI check
        && _lowLevel.has_key(uri)
    ) {
        return _lowLevel[uri].apply!!;
    }

    String[] nodes = uri.split("/"); // Leaked Allocation ?

    RouteNode*! temp = _lowLevel[nodes[0]];
    if (catch temp) return &e404;

    int i = 0;
    while (temp != null && i < nodes.len - 1) {
        temp = get_next_node(temp, nodes[i++])!!;
        if (temp.name[0] == '{' && temp.name[temp.name.len-1] == '}'
        ) (*args)[temp.name[1:temp.name.len-2]] = nodes[i]; // Leaked Allocation
    }

    if (temp == null) {
        return &e404;
    }
    RouteFunction res = temp.apply;
    return res;
}

macro RouteNode* new_route(String name, HashMap(<String, RouteNode*>) subnodes = {}, RouteFunction apply = null) {
    return @tclone(RouteNode {.name = name, .subnodes = subnodes, .apply = apply});
}

fn void add_route(String route, RouteFunction apply) {
    if (route[0] == '/') route = route[1:route.len-1];

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

    int i = 0;
    while (i < nodes.len - 1) {
        RouteNode*! _temp = get_next_node(temp, nodes[i++]);
        if (catch _temp) {
            _temp = new_route(nodes[i]);
            temp.subnodes[
                (nodes[i][0]=='{' && nodes[i][nodes[i].len-1]=='}') ?
                "{}" : nodes[i]
            ] = _temp!!;
        }
        temp = _temp!!;
    }

    temp.apply = apply;
}