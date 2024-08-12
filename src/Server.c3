module c3api;

struct ControllerParadise {
    bool _ignore;
}

def Cref = ControllerParadise*;

def @Controller(uri) = { @tag("controller", uri) };

fn void ControllerParadise.init(ControllerParadise* self) {
    $foreach($method : $typeof(*self).methodsof)
        $if $typeof(*self).$eval($method).has_tagof("controller"):
            routes::add_route($typeof(*self).$eval($method).tagof("controller"), &$typeof(*self).$eval($method));
        $endif
    $endforeach
}

module c3api::server;

import std::io;
import std::thread;
import std::net::tcp;

import c3api::routes;

const uint BACKLOG = 10000;
bool should_close = false;
bool enable_cors = false;

import std::collections::map;

fn int process(void* arg) {
    ArenaAllocator arena;
    arena.init(&&char[256 * 1024]{});
    defer {
        allocator::free(&allocator::LIBC_ALLOCATOR, arg);
        allocator::destroy_temp_allocators();
    }
    mem::@scoped(&arena) {
        TcpSocket* socket = arg;

        defer {
          socket.close()!!;
        }

        HttpRequest req;
        if (catch anyfault err = req.read(socket)) {
            return 1;
        }

        String uri = req.uri[1:req.uri.len-1];

        HashMap(<String,String>) args;
        args.new_init();

        RouteFunction route = routes::get_route(uri, &args);

        HttpResponse res;
        res.headers.temp_init();

        if (enable_cors) {
            if (req.method == HttpVerb.OPTIONS) {
                res.status = HttpStatus.OK;
                res.body = "200";

                // TODO REPLACE HEADERS WITH CONFIGURABLE ONE
                res.headers.add_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS"); // Specify allowed methods
                res.headers.add_header("Access-Control-Allow-Headers", "Content-Type");
            } else {
                res = route(null, req, args);
            }
            res.headers.add_header("Access-Control-Allow-Origin", "*");
        } else {
            res = route(null, req, args);
        }

        res.write(socket)!!;
    };

    return 0;
}

import c3api::os::win32;

fn void! startServer(String host, uint port, bool cors) {
    enable_cors = cors;

    win32::startWSA();
    defer win32::stopWSA();

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
            win32::lastWSAErrorOut();
            continue;
        }

        thread::Thread thread;
        thread.create(&process, allocator::clone(&allocator::LIBC_ALLOCATOR, socket))!!;
        thread.detach()!!;
    }

    io::printn("Closing server...");
    server.close()!!;
}