# Chat-Python-Assembly

###### NASM version 2.13.01 compiled on May 1 2017

###### ALINK v1.6 (C) Copyright 1998-9 Anthony A.J. Williams.

## Overview

This repository implements a chat system using Python, C++, and Assembly. It demonstrates cross-language integration and network programming with a focus on efficiency and reliability.

## Features

- **UNIX Python Server:**
  - Utilizes multiplexing for handling multiple chat connections efficiently.
  - Sends and receives messages using the `socket` library.
  - Supports multiple clients and handles disconnections gracefully.
- **Windows C++** and **NASM** clients:
  - Implement Windows Sockets API (Winsock) for network communication.
  - Multi-threaded design ensures responsive user interactions.
  - Memory management optimized to prevent leaks.

## Getting Started

- **Prerequisites:** Python, a C++ compiler, NASM, and Windows environment for the clients.
- **Installation:** Clone the repo and compile the C++ and NASM clients.

## Usage

1. Start the Python server on UNIX.
2. Run the C++ or NASM client on Windows.
3. Enter a name and start chatting!

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](./LICENSE) file for details.
