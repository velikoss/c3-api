# c3-api

## Overview

The `c3-api` project is a simple C3 HTTP Server with routing. This project aims to provide a comprehensive and modular way to manage and manipulate HTTP communications.

The project is tested and confirmed to be working in Windows, Linux and Mac equally

Inspired from [ArjixWasTaken/c3-simple-http](https://github.com/ArjixWasTaken/c3-simple-http)

## 09.08.2024 Introducing Controllers!
### Now you can write function without even touching `main.c3`.

<b>Every Route function should start with: </b><br/>
```
fn HttpResponse c3api::ControllerParadise.foo(c3api::Cref self = null, HttpRequest req, HashMap(<String,String>) args) @Controller("/baz") {}
```
Here .foo is the unique name of the route method, and "/baz" is the path to the route itself <br/>
req is the HttpRequest and args is the Map of dynamic arguments (see example [here](https://github.com/velikoss/c3-api/blob/main/src/examples/dynamic_route.c3)) <br/>
And yes, `c3api::ControllerParadise.yourRouteName` and `c3api::Cref self = null` as first argument is necessary for routing system to work. 

For more info you can look into [examples](https://github.com/velikoss/c3-api/tree/main/src/examples).

### [Ping example](https://github.com/velikoss/c3-api/blob/main/src/examples/ping.c3)

```c
module c3test;
import c3api;
import std::collections::map;

fn HttpResponse c3api::ControllerParadise.ping(c3api::Cref self = null, HttpRequest req, HashMap(<String,String>) args) @Controller("/ping") {
    HttpResponse res;
    res.status = HttpStatus.OK;
    res.body = string::new_format("Pong!\n", req.method, req.uri);
    return res;
}
```

### [Dynamic Argument example](https://github.com/velikoss/c3-api/blob/main/src/examples/dynamic_route.c3)

```c
module c3test;
import c3api;
import std::collections::map;

fn HttpResponse c3api::ControllerParadise.greetings(c3api::Cref self = null, HttpRequest req, HashMap(<String,String>) args) @Controller("/hi/{username}") {
    @pool() { // Using pool because of dstring::temp_new();
        HttpResponse res;
        res.status = HttpStatus.OK;
        DString greetings = dstring::temp_new();
        greetings.appendf("Hi, %s!\n", args["username"]!!);
        res.body = string::new_format(greetings.tcopy_str(), req.method, req.uri);
        return res;
    };
}
```

## Plans

- [ ] CORS Module
- [ ] Custom modules support
- [ ] Config File
- [ ] Logging system
- [ ] Embedding **c3-api** into other modules

## Installation

To install and set up the `c3-api` project, follow these steps:

1. Clone the repository:
   ```bash
   git clone https://github.com/velikoss/c3-api.git
   ```

2. Ensure you have the C3 compiler installed. You can find the installation instructions [here](https://c3-lang.org/).

## Usage

To compile and run the project, use the following commands:

1. Compile the project:
   ```bash
   c3c compile -O3 c3-api
   ```

2. Run the executable:
   ```bash
   ./c3api
   ```

## Specs

```C
enum HttpVerb {
    HEAD,
    GET,
    PATCH,
    POST,
    PUT,
    DELETE,
    OPTIONS,
    TRACE,
    CONNECT
}

struct HttpRequest {
    HttpVerb method;
    String uri;
    HttpHeaders headers;
    char[] body;
}

struct HttpResponse {
    HttpStatus status;
    HttpHeaders headers;
    char[] body;
}
```


-- --

# Old Readme for [This version and lower](https://github.com/velikoss/c3-api/tree/f7021bc6f2ff54d9c42952dee65c852cecd2ddf4)

## Adding Routes

To add routes to the server, follow these steps:

1. Define your routes using the appropriate HTTP verbs and handlers in your code. For example:
   ```c3
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
   ```

2. Add the routes in the main function in `main.c3`:
   ```c3
   fn int main(String[] args) {
       // TODO CONFIG
       String host = "127.0.0.1";
       uint port = 8080;

       add_route("/ping", &pong);
       add_route("/ping/{pong}", &pong1);

       startServer(host, port)!!;
       return 0;
   }
   ```

## Starting the Server

To start the server, ensure your main function is set up correctly in `main.c3`:

1. Initialize and set the routes.
2. Start the server.

## Future Plans

Here are some planned features and improvements for the `c3-api` project:

- [x] 0. **FIX MEMORY LEAKS**: 3k requests spikes up RAM usage from 6Kb to 1.6Gb without any freeing. Any contributions and suggestions are welcomed.
   - Fixed. 3k request now spikes up RAM usage to ~50MB
   - Fixed again as of [#726567a](https://github.com/velikoss/c3-api/commit/726567adebdcf89005da53933d04d1cb54f4ae05). Now 230k GET requests spikes up memory usage at around ~1.1Mb with it going down to 0.6Mb after benchmarking (Thanks [@lerno](https://github.com/lerno) for help!)
   - [ ] TODO Benchmark info
- [x] 1. **Enhanced Routing**: Implement advanced routing capabilities, including support for query parameters and wildcard routes.
   - [ ] method(string, fn) instead of add_route(string, fn)
- [ ] 2. **Middleware Support**: Add support for middleware to handle tasks such as authentication, logging, and request validation.
   - [ ] CORS
   - [ ] JWT
- [ ] 3. **HTTPS Support**: Enable HTTPS support for secure communications.
- [ ] 4. **Configuration Management**: Develop a configuration management system to easily manage server settings and environment variables.
- [ ] 5. **Testing Framework**: Create a robust testing framework to ensure the reliability and stability of the API.
- [ ] 6. **Documentation**: Improve documentation with detailed examples and usage guides.

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository.
2. Create a new branch (`git checkout -b feature-branch`).
3. Commit your changes (`git commit -am 'Add new feature'`).
4. Push to the branch (`git push origin feature-branch`).
5. Create a new Pull Request.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Contact

For questions or feedback, please contact [velikoss@vk.com](mailto:velikoss@vk.com) or Discord: @velikoss .

---
