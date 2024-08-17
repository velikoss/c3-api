module c3api::routes;
import std::collections::map;
import std::io;
import std::collections::object;

def RouteFunction = fn HttpResponse(ControllerParadise*, HttpRequest, HashMap(<String,String>));
def RouteMap = HashMap(<String, RouteNode*>);
def TagsMap = HashMap(<String, Object*>);

struct RouteNode {
    String name;
    RouteMap subnodes;
    bool has_apply;
    RouteFunction apply;
}

fn HttpResponse e404(ControllerParadise* controller = null, HttpRequest req, HashMap(<String,String>) args) {
    HttpResponse res;

    res.status = HttpStatus.NOT_FOUND;
    res.body = string::new_format(`{"type":"error","status":404}`, "\n", req.method, req.uri);

    res.headers.add_header("Content-Type", "application/json");

    return res;
}

fn HttpResponse file(ControllerParadise* controller = null, HttpRequest req, HashMap(<String,String>) args) {
    HttpResponse res;

    String filename = args["filename"]!!;
    //io::printfn("%s:%d %s", $$MODULE, $$LINE, filename);

    File! file;

    if (file::is_file(filename)) {
        file = file::open(filename, "rb");
    } else {
        Path path = path::tgetcwd()!!;
        path = path.append(filename)!!;

        file = file::open_path(path, "rb");
        filename = path.str_view();
    }

    defer {
      (void)file.flush();
      (void)file.close();
    }

    if (catch anyfault err = file) {
        res.status = HttpStatus.NOT_FOUND;
        io::eprintfn("Failed to get file: %s", err);
        res.body = string::new_format(`{"type":"error","status":404}`, "\n", req.method, req.uri);

        res.headers.add_header("Content-Type", "application/json");
    } else if (file::get_size(filename)!! > 5 * 1024 * 1024) { // TODO CONFIG (right now 5Mb is the limit for the file)
        res.status = HttpStatus.PAYLOAD_TOO_LARGE;

        res.body = string::new_format(`{"type":"error","status":413}`, "\n", req.method, req.uri);

        res.headers.add_header("Content-Type", "application/json");
    } else {
        DString text;
        if (catch anyfault err1 = text.read_from_stream(&file)) {
            io::eprintfn("Failed to read: %s", err1);
            res.status = HttpStatus.BAD_REQUEST;
            res.body = string::new_format(`{"type":"error","status":400}`, "\n", req.method, req.uri);
        } else {
            res.status = HttpStatus.OK;
            res.body = text.str_view();
            res.headers.add_header("Content-Type", "text/plain");
        }
    }

    return res;
}

fn HttpResponse folder(ControllerParadise* controller = null, HttpRequest req, HashMap(<String,String>) args) {
    HttpResponse res;
    String filename = args["foldername"]!!;

    PathList! list;

    if (os::native_is_dir(filename)) {
        list = path::ls(path::temp_new(filename));
    } else {
        Path path = path::tgetcwd()!!;
        path = path.append(filename)!!;
        filename = path.str_view();
        if (path::is_dir(path)) {
            list = path::ls(path);
        }
    }

    if (catch anyfault err = list) {
        res.status = HttpStatus.NOT_FOUND;
        res.body = string::new_format(`{"type":"error","status":404}`, "\n", req.method, req.uri);

        res.headers.add_header("Content-Type", "application/json");
    } else {
        DString body = dstring::new();
        body.appendfn(`
<style>
table, th, td {
  border: 1px solid black;
  border-collapse: collapse;
  table-layout: auto;
  vertical-align: bottom;
  padding: 5px;
}
</style>
<h1>Contents of %s</h1><hr>
<table>
<tr>
    <th>Name</th>
    <th>Size</th>
</tr>
        `, filename);

        foreach (Path file: list) {
            body.appendfn(
`<tr>
    <td>%s %s</td>
    <td>%d</td>
</tr>`
            , (path::is_dir(file) ? "📁 " : "🔗 "), file.str_view(), file::get_size(file.str_view())!!);
        }

        body.append("</table>");

        res.status = HttpStatus.OK;

        res.body = body.str_view();
        res.headers.add_header("Content-Type", "text/html; charset=utf-8");
    }

    return res;
}

fn RouteFunction get_route(String uri, HashMap(<String,String>)* args) {
    DString reverse_path = dstring::new(uri);
    if (uri[0] != '/') reverse_path.insert_at(0, "/");
    args.set("reverse_path", reverse_path.str_view());
    reverse_path.free();

    if (uri == "" || uri == "/") { return (_lowLevel[uri].has_apply??false)?_lowLevel[uri].apply!!:&e404; }

    String old_uri;
    if (uri[0] == '/' && uri.len > 1) {
         old_uri = uri;
         uri = uri[1..];
    }

    if (
        !(uri.contains("{") && uri.contains("}")) // Dynamic URI check
        && _lowLevel.has_key(uri)
    ) {
        return (_lowLevel[uri].has_apply??false)?_lowLevel[uri].apply!!:&e404;
    }

    String[] nodes = uri.tsplit("/");

    RouteNode*! temp = _lowLevel[nodes[0]];
    if (catch err = temp) {
        if (err != SearchResult.MISSING) io::printfn("Catch err: %s", err);
        return &e404;
    }

    reverse_path.new_init();
    reverse_path.appendf("/%s", temp.name);
    int i = 0;
    while (temp != null && i < nodes.len - 1) {
        temp = get_next_node(temp, nodes[i++])??null;
        if (temp == null) { continue; }
        if (temp.name[0] == '{' && temp.name[^1] == '}'
        ) (*args)[temp.name[1:^2]] = nodes[i]; // Leaked Allocation
        reverse_path.appendf("/%s", temp.name);
    }

    if (temp == null) {
        args.set("reverse_path", "/e404");
        return &e404;
    }

    args.set("reverse_path", reverse_path.str_view());

    RouteFunction res = temp.apply;
    return res;
}

fn void add_route(String uri, RouteFunction apply) {
    if (uri[0] == '/' && uri.len > 1) uri = uri[1..];

    if (
            !(uri.contains("{") && uri.contains("}")) // Dynamic URI check
    ) {
        _lowLevel[uri] = new_route(.name = uri, .apply = apply);
        return;
    }

    String[] nodes = uri.split("/");
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

fn void init_route_map() {
    _lowLevel.new_init();
    tagsMap.new_init();
}
fn void destroy_route_map() {
    _lowLevel.free();
    tagsMap.free();
}

TagsMap tagsMap;

fn void add_tag(String func, String key, String value) {
    if (!tagsMap.has_key(func)) { tagsMap[func] = object::new_obj(allocator::heap()); }
    tagsMap[func]!!.set(key, value);
}

module c3api::routes @private;
import std::collections::map;
import std::io;

RouteMap _lowLevel;

fn RouteNode*! get_next_node(RouteNode* from, String to) {
    return from.subnodes[to] ?? from.subnodes["{}"];
}

macro RouteNode* new_route(String name, HashMap(<String, RouteNode*>) subnodes = {}, RouteFunction apply = null) {
    return @clone(RouteNode {.name = name, .subnodes = subnodes, .has_apply = apply != null, .apply = apply});
}

fn bool String.is_braced(self) {
    return self[0] == '{' && self[^1] == '}';
}

