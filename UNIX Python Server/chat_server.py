#!/usr/bin/env python3

import socket
from select import select
from sys import stdin

IP = "0.0.0.0"
PORT = 7777
ADDR = (IP, PORT)

BUFFLEN = 255  # intentionally 255 and not 256
SOCK_BACKLOG = 8

in_sock = list()
clients = dict()  # keys are out_sock


def prepare_broadcast(buffer: bytes, ignored_client=None) -> None:
    buffer = buffer[:BUFFLEN]

    for client in clients:
        if client == ignored_client:
            continue

        clients[client]["backlog"].append(buffer)


def close_connection(cs: socket, prompt: str = "unknown") -> None:
    addr = clients[cs]["addr"] if cs in clients else "unknown"
    clients.pop(cs, None)

    try:
        in_sock.remove(cs)
    except ValueError:
        pass

    try:
        cs.close()
    except OSError:
        pass

    print(f"Disconnected from {addr}. Reason: {prompt}")
    prepare_broadcast(f"{addr} disconnected. Reason: {prompt}".encode())


def get_client_message(cs: socket) -> None:
    buff = cs.recv(BUFFLEN)
    if not buff:
        raise ConnectionResetError

    print(f"{clients[cs]['addr']} {buff.decode()}")
    prepare_broadcast(buff, ignored_client=cs)


def connect_to_client(params: dict, sock: socket) -> None:
    cs, addr = sock.accept()

    clients[cs] = {
        "addr": addr,
        "backlog": [params["motd"].encode()[:BUFFLEN]],
    }

    in_sock.append(cs)
    print(f"Connected to {addr}")


def get_server_input(params: dict) -> None:
    msg_to_send = input().strip()

    # the maximum buffer length is applied in the prepare_broadcast function
    prepare_broadcast(f"{params['name']}: {msg_to_send}".encode())


def set_name(params: dict, name: str) -> None:
    params["name"] = name
    params["name_terminator"] = "'" if name.endswith("s") else "'s"

    params["motd"] = f"Welcome to {name}{params['name_terminator']} chat room!"


def main() -> None:
    params = {
        "name": "",
        "name_terminator": "",
        "motd": "",
    }

    name = input("Name: ").strip()
    set_name(params, name)

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    # do this before bind so that we can reuse
    # the port in case the program crashes
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    print("TCP socket created")

    sock.bind(ADDR)
    sock.listen(SOCK_BACKLOG)
    print(f"Listening on {PORT}...")

    in_sock.append(stdin)
    in_sock.append(sock)

    try:
        while True:
            r, w, e = select(in_sock, clients.keys(), [])

            try:
                for ready in e:
                    close_connection(ready, "socket error")

                for ready in r:
                    if ready == stdin:
                        get_server_input(params)
                    elif ready == sock:
                        connect_to_client(params, ready)
                    else:
                        get_client_message(ready)

                for ready in w:
                    messages = clients[ready]["backlog"]
                    if messages:
                        ready.send(messages.pop(0))
            except (OSError, ConnectionResetError, BrokenPipeError):
                close_connection(ready, "connection reset")

            pass  # for readability
    except KeyboardInterrupt:
        print("\rStopping...")

    for client in in_sock:
        if client in [stdin, sock]:
            continue

        close_connection(client, "server shutting down")

    sock.close()
    print("Socket closed")


if __name__ == "__main__":
    main()
