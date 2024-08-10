module c3api;

import c3api::routes;
import c3api::server;

fn int main(String[] args) {
    // TODO CONFIG

    routes::init_route_map();

    ControllerParadise paradise;
    paradise.init();

    defer routes::destroy_route_map();

	String host = "127.0.0.1";
    uint port = 8080;

    server::startServer(host, port)!!;
    return 0;
}