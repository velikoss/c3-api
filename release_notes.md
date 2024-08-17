## 17.08.2024
- Fixed `@File` and `@Folder` crashes on Linux
- Minor fixes

## 16.08.2024 Introducing Files and Folder Views!</br>(+ c3-api is officially a library now!)
### Now to add c3-api to your project you should do this:
- Download latest <b>c3api.c3l</b> from [Releases](https://github.com/velikoss/c3-api/releases)
- Move c3l to your projects lib/ folder
- Add c3api to your dependencies in project.json
```json
{
    ...
  "dependencies": ["c3api"],
    ...
}
```
- Use it in your project!
- For example project using library look [here](https://github.com/velikoss/c3-api-example)

## Added Files and Folder Views
- Now you can link to file using `@File("path")` and view folder contents using `@Folder("path")`
- It also supports dynamic arguments
- For example look [here](https://github.com/velikoss/c3-api-example/blob/main/src/examples/folder.c3)
### c3-api-example/src/examples/folder.c3
```
module c3apitest;
import c3api;
import std::collections::map;

fn HttpResponse c3api::ControllerParadise.src(c3api::Cref self = null, HttpRequest req, HashMap(<String,String>) args)
@Controller("/src") @Folder(".") { // Executable folder
    return {.body = "200"};
}

fn HttpResponse c3api::ControllerParadise.srcfile(c3api::Cref self = null, HttpRequest req, HashMap(<String,String>) args)
@Controller("/src/{file}") @File("./{file}") { // It also can be dynamic!
    return {.body = "200"};
}
```
_P.S. Function body with this annotations will NOT execute_