module c3api::os::win32;

import std::os::win32;

import std::io;

struct WsaData @if(env::WIN32) {
    char[408] data;
}

extern fn CInt win32_WSAStartup() @extern("WSAStartup") @if(env::WIN32 && !$defined(win32_WSAStartup));
extern fn CInt win32_WSACleanup() @extern("WSACleanup") @if(env::WIN32 && !$defined(win32_WSACleanup));
extern fn CInt win32_WSAGetLastError() @extern("WSAGetLastError") @if(env::WIN32 && !$defined(win32_WSAGetLastError));

fn void startWSA() {
    $if !env::WIN32:
        return;
    $else
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
    $endif
}

fn void stopWSA() {
    $if !env::WIN32:
        return;
    $else
        io::printn("WSA cleanup...");
        win32_WSACleanup();
    $endif
}

fn void lastWSAErrorOut() {
    $if !env::WIN32:
        return;
    $else
        io::printfn("WSAGetLastError Output: %d", win32_WSAGetLastError());
    $endif
}