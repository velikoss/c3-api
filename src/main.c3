module c3api;

import std::io;
import std::thread;

import std::net;
import std::net::tcp;

// TODO FIX MEMORY LEAK

import std::os::win32;

struct WsaData @if(env::WIN32) {
    char[408] data;
}

extern fn CInt win32_WSAGetLastError() @extern("WSAGetLastError") @if(env::WIN32);

const uint BACKLOG = 10000;
bool should_close = false;

fn HttpResponse pong(HttpRequest req, HashMap(<String,String>) args) {
    HttpResponse res;
    res.status = HttpStatus.OK;
    res.body = string::new_format("Pong!\n", req.method, req.uri);
    return res;
}

fn HttpResponse pong1(HttpRequest req, HashMap(<String,String>) args) {
    HttpResponse res;
    res.status = HttpStatus.OK;
    res.body = string::new_format(args["pong"]!!, "\n", req.method, req.uri);
    return res;
}

import std::collections::map;

fn int process(void* arg) {
//mem::@report_heap_allocs_in_scope() {
    TcpSocket* socket = arg;
    defer socket.close()!!;

    HttpRequest req;
    if (catch anyfault err = req.read(socket)) {
        return 1;
    }

    String uri = req.uri[1:req.uri.len-1];

    HashMap(<String,String>) args;
    args.new_init();

    RouteFunction route = get_route(uri, &args);
    HttpResponse res = route(req, args);

    res.write(socket)!!;

    args.free();
    req.free();
    res.free();

    return 0;
//};
}

fn void! startServer(String host, uint port) {
$if env::WIN32:
    io::printn("Env is Win32");
    WsaData wsa_data;
    Win32_WORD version = 0x0202;

    int wsa_error = win32_WSAStartup(version, &wsa_data);

    io::print("WinSock Log: ");
    foreach (char i: wsa_data.data) {
        io::printf("%c", i);
    }
    io::printn();

    if (wsa_error != 0) {
        io::printfn("failed to startup WSA with error: %d", wsa_error);
        return;
    }
    io::printn("WSA started successfully");

    defer io::printn("WSA cleanup...");
    defer win32_WSACleanup();
$endif

    TcpServerSocket! server = tcp::listen(host, port, BACKLOG, net::SocketOption.REUSEADDR, .ip_protocol=net::IpProtocol.IPV4);

    if (catch err = server) {
        io::printfn("failed to bind <%s:%d> with failure: %s", host, port, err);
        return;
    }
    io::printfn("listening on <%s:%d>", host, port);

    while (!should_close) {
        TcpSocket! socket = tcp::accept(&server);
        if (catch err = socket) {
            should_close = true;
            io::printfn("Error was %s", err);
$if env::WIN32:
            io::printfn("WSAGetLastError Output: %d", win32_WSAGetLastError());
$endif
            continue;
        }

        //mem::@report_heap_allocs_in_scope() {
        thread::Thread thread;
        thread.create(&process, @tclone(socket))!!;
        thread.detach()!!;
        //};
    }

    io::printn("Closing server...");
    server.close()!!;


}

fn void init_route_map() => _lowLevel.new_init();
fn void destroy_route_map() => _lowLevel.free();

fn int main(String[] args) {
    // TODO CONFIG
    init_route_map();
    defer destroy_route_map();
	String host = "127.0.0.1";
    uint port = 8080;

    add_route("/ping", &pong);
    add_route("/ping/{pong}", &pong1);

    startServer(host, port)!!;
    return 0;
}