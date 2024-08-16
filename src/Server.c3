module c3api;

struct ControllerParadise {
    bool _ignore;
}

def Cref = ControllerParadise*;

def @Controller(uri) = { @tag("controller", uri) };
def @File(uri) = { @tag("file", uri) };
def @Folder(uri) = { @tag("folder", uri) };

macro bool @method_has_tag(#self, $method, $tag) {
  return $typeof(*#self).$eval($method).has_tagof($tag);
}

fn void ControllerParadise.init(ControllerParadise* self) {
    $foreach($method : $typeof(*self).methodsof)
        $if @method_has_tag(self, $method, "controller"):
            var $tag = $typeof(*self).$eval($method).tagof("controller");
            routes::add_route($tag, &$typeof(*self).$eval($method));
            routes::add_tag($tag, "controller", $tag);
            $if @method_has_tag(self, $method, "file"):
                var $filetag = $typeof(*self).$eval($method).tagof("file");
                routes::add_tag($tag, "file", $filetag);
            $else
                $if @method_has_tag(self, $method, "folder"):
                    var $foldertag = $typeof(*self).$eval($method).tagof("folder");
                    routes::add_tag($tag, "folder", $foldertag);
                $endif
            $endif
        $endif
    $endforeach
}

module c3api::server @private;

import std::io;
import std::thread;
import std::net::tcp;

import c3api::routes;

const uint BACKLOG = 10000;
bool should_close = false;

import c3api::utils;
import std::collections::map;

fn int process(void* arg) {
    OnStackAllocator alloc;
    alloc.init(&&char[256 * 1024]{}, allocator::heap());

    defer {
        allocator::free(&allocator::LIBC_ALLOCATOR, arg);
        allocator::destroy_temp_allocators();
        alloc.free();
    }

    mem::@scoped(&alloc) {
        TcpSocket* socket = arg;

        defer {
            if (catch anyfault err = socket.close()) {
                io::printfn("Socket Closing Error: %s", err);
            }
        }

        HttpRequest req;
        if (catch anyfault err = req.read(socket)) {
            req.free();
            io::printfn("Request Read Error: %s", err);
            return 1;
        }

        String uri = req.uri[1..];

        HashMap(<String,String>) args;
        args.new_init();

        RouteFunction route;
        route = routes::get_route(uri, &args);

        Object* tags = routes::tagsMap[args["reverse_path"]!!]??null;

        HttpResponse res;
        res.headers.temp_init();

        defer {
          args.free();
          req.free();
          res.free();
        }

        if (tags != null) {
            if ((tags.get_string("file")??"") != "") {
                args["filename"] = utils::format_path(tags.get_string("file")!!, &args)??tags.get_string("file")!!;
                route = &routes::file;
            }
            else if ((tags.get_string("folder")??"") != "") {
                String folder = tags.get_string("folder")!!;
                args["foldername"] = utils::format_path(folder, &args)??folder;
                route = &routes::folder;
            }
        }

        if (cors_config.get_bool("enabled")??false) {
            if (req.method == HttpVerb.OPTIONS) {
                res.status = HttpStatus.OK;
                res.body = `{"status":200}`;

                res.headers.add_header("Access-Control-Allow-Methods", cors_config.get_string("Access-Control-Allow-Methods")??"");
                res.headers.add_header("Access-Control-Allow-Headers", cors_config.get_string("Access-Control-Allow-Headers")??"");

                res.headers.add_header("Content-Type", "application/json");
            } else {
                res = route(null, req, args);
            }
            res.headers.add_header("Access-Control-Allow-Origin", cors_config.get_string("Access-Control-Allow-Origin")??"");
        } else {
            res = route(null, req, args);
        }


        if (catch err = res.write(socket)) {
          io::eprintfn("Failed to write: %s", err);
        }
    };

    return 0;
}

import std::collections::object;
Object* cors_config;

import c3api::config;
import c3api::os::win32;

fn void! startServer(config::Config config) @public {
    cors_config = config.cors;

    win32::startWSA();

    TcpServerSocket! server = tcp::listen(config.address, config.port, BACKLOG, net::SocketOption.REUSEADDR, .ip_protocol=net::IpProtocol.IPV4);

    defer {
        io::printn("Closing server...");
        server.close()!!;
        win32::stopWSA();
        free(cors_config);
    }

    if (catch err = server) {
        io::printfn("failed to bind <%s:%d> with failure: %s", config.address, config.port, err);
        return;
    }
    io::printfn("listening on <%s:%d>", config.address, config.port);

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
}