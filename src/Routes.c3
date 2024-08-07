module c3api;
import std::collections::map;

def RouteFunction = fn HttpResponse(HttpRequest, HashMap(<String,String>));

struct RouteNode {
    String name;
    HashMap(<String, RouteNode*>) subnodes;
    RouteFunction apply;
}

HashMap(<String, RouteNode*>) _lowLevel;

fn HttpResponse e404(HttpRequest req, HashMap(<String,String>) args) {
    HttpResponse res;
    res.status = HttpStatus.NOT_FOUND;
    res.body = string::new_format("{\"type\":\"error\",\"status\":404}\n", req.method, req.uri);
    return res;
}

fn RouteNode* get_next_node(RouteNode* from, String to) {
    if (from.subnodes.has_key(to)) return from.subnodes[to]!!;
    RouteNode*! ret = from.subnodes["{}"];
    return @ok(ret) ? ret!! : null;
}

import std::io;

fn RouteFunction get_route(String uri, HashMap(<String,String>)* args) {
    if (uri[0] == '/') uri = uri[1:uri.len-1];

    if (
        !(@ok(uri.index_of_char('{')) && @ok(uri.index_of_char('}'))) // Dynamic URI check
        && _lowLevel.has_key(uri)
    ) {
        return _lowLevel[uri].apply!!;
    }

    String[] nodes = uri.split("/");
    if (!_lowLevel.has_key(nodes[0])) return &e404;

    RouteNode* temp = _lowLevel[nodes[0]]!!;

    int i = 0;
    while (temp != null && i < nodes.len - 1) {
        temp = get_next_node(temp, nodes[i++]);
        if (temp.name[0] == '{' && temp.name[temp.name.len-1] == '}'
        ) (*args)[temp.name[1:temp.name.len-2]] = nodes[i];
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
        RouteNode* _temp = get_next_node(temp, nodes[i++]);
        if (_temp == null) {
            _temp = new_route(nodes[i]);
            temp.subnodes[
                (nodes[i][0]=='{' && nodes[i][nodes[i].len-1]=='}') ?
                "{}" : nodes[i]
            ] = _temp;
        }
        temp = _temp;
    }

    temp.apply = apply;
}