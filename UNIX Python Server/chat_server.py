#!/usr/bin/env python3

import socket
from threading import Thread

IP = "0.0.0.0"
PORT = 7777
ADDR = (IP, PORT)

BUFFLEN = 255  # intentionally 255 and not 256
SOCK_BACKLOG = 8

threads = list()
clients = dict()


def broadcast(buffer: bytes, ignored_client=None) -> None:
    for client in clients:
        if client == ignored_client:
            continue

        try:
            client.send(buffer[:BUFFLEN])
        except BrokenPipeError:
            close_connection(client, "broken pipe")


def close_connection(cs: socket, prompt: str = "unknown") -> None:
    cs.close()

    print(
        f"Disconnected from {clients[cs] if cs in clients else 'unknown'}. "
        f"Reason: {prompt}"
    )
    clients.pop(cs, None)


def client_thread(params: dict, cs: socket) -> None:
    cs.send(params["motd"].encode()[:BUFFLEN])

    while not params["quit"]:
        try:
            buff = cs.recv(BUFFLEN)
            if not buff:
                raise ConnectionResetError
        except (ConnectionResetError, OSError):
            close_connection(cs, "connection reset")
            break

        print(f"{clients[cs]} {buff.decode()}")
        broadcast(buff, ignored_client=cs)


def start_client_thread(params: dict, cs: socket) -> None:
    t = Thread(
        target=client_thread,
        args=(params, cs),
    )
    threads.append(t)
    t.start()


def input_thread(params: dict) -> None:
    while not params["quit"]:
        msg_to_send = input().strip()
        broadcast(f"{params['name']}: {msg_to_send}".encode())


def start_input_thread(params: dict) -> None:
    t = Thread(
        target=input_thread,
        args=(params,),
    )
    threads.append(t)
    t.start()


def set_name(params: dict, name: str) -> None:
    params["name"] = name
    params["name_terminator"] = "'" if name.endswith("s") else "'s"

    params["motd"] = f"Welcome to {name}{params['name_terminator']} chat room!"


def main() -> None:
    # TODO: implement using select instead of threads
    params = {
        "name": "",
        "name_terminator": "",
        "motd": "",
        "quit": False,
    }

    name = input("Name: ").strip()
    set_name(params, name)
    start_input_thread(params)

    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    # do this before bind so that we can reuse
    # the port in case the program crashes
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    print("TCP socket created")

    sock.bind(ADDR)
    sock.listen(SOCK_BACKLOG)
    print(f"Listening on {PORT}...")

    while not params["quit"]:
        try:
            cs, addr = sock.accept()
            print(f"Connected to {addr}")

            clients[cs] = addr
            start_client_thread(params, cs)
        except KeyboardInterrupt:
            print("\rStopping...")
            break

    params["quit"] = True
    for t in threads:
        t.join()

    for client in clients:
        close_connection(client, "server shutting down")

    sock.close()
    print("Socket closed")


if __name__ == "__main__":
    main()
