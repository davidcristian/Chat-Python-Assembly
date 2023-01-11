#define WIN32_LEAN_AND_MEAN

#include <windows.h>
#include <winsock2.h>
#include <ws2tcpip.h>

#pragma comment (lib, "Ws2_32.lib")
#pragma comment (lib, "Mswsock.lib")
#pragma comment (lib, "AdvApi32.lib")

#include <iostream>
#include <thread>
#include <string.h>

#define SERVER_IP "192.168.0.250"
#define SERVER_PORT 7777

#define CONN_FAMILY AF_INET
#define BUFFER_SIZE 255  // intetionally 255 and not 256

void inputThread(SOCKET& sock, std::string& name, bool& quit)
{
	std::string sendBuff;
	int sendLen = 0;

	while (!quit)
	{
		std::cin >> sendBuff;
		sendBuff = name + ": " + sendBuff;
		sendLen = sendBuff.length() < BUFFER_SIZE ? sendBuff.length() : BUFFER_SIZE;
		
		if (send(sock, sendBuff.c_str(), sendLen, 0) == SOCKET_ERROR)
		{
			std::cout << "ERROR: send()" << std::endl;
			quit = true;
		}
	}
}

void recvThread(SOCKET& sock, bool& quit)
{
	char recvBuff[BUFFER_SIZE + 1] = { 0 };
	int recvBytes = 0;

	while (!quit)
	{
		recvBytes = recv(sock, (char*)&recvBuff, BUFFER_SIZE, 0);
		recvBuff[recvBytes] = 0;

		if (recvBytes > 0)
		{
			std::cout << std::string(recvBuff) << std::endl;
			continue;
		}

		quit = true;
		if (recvBytes == 0)
			std::cout << "INFO: Connection closed" << std::endl;
		else
			std::cout << "ERROR: recv()" << std::endl;
	}
}

int main()
{
	std::cout << "TCP client" << std::endl;
	std::string name;

	std::cout << "Name: ";
	std::cin >> name;

	WSAData wsaData;
	if (WSAStartup(MAKEWORD(2, 2), &wsaData) != 0)
	{
		std::cout << "ERROR: WSAStartup()" << std::endl;
		return 1;
	}

	SOCKET sock = socket(CONN_FAMILY, SOCK_STREAM, IPPROTO_TCP);
	if (sock == INVALID_SOCKET)
	{
		std::cout << "ERROR: socket()" << std::endl;
		WSACleanup();
		return 2;
	}

	SOCKADDR_IN connection;
	connection.sin_family = CONN_FAMILY;
	connection.sin_port = htons(SERVER_PORT);

	if (inet_pton(CONN_FAMILY, SERVER_IP, &connection.sin_addr) != 1)
	{
		std::cout << "ERROR: inet_pton()" << std::endl;
		WSACleanup();
		return 3;
	}

	if (connect(sock, (SOCKADDR*)&connection, sizeof(connection)) == SOCKET_ERROR)
	{
		std::cout << "ERROR: connect()" << std::endl;
		closesocket(sock);
		WSACleanup();
		return 4;
	}
	
	bool quit = false;
	std::thread in_t(inputThread, std::ref(sock), std::ref(name), std::ref(quit));
	std::thread out_t(recvThread, std::ref(sock), std::ref(quit));

	in_t.join();
	out_t.join();

	closesocket(sock);
	WSACleanup();

	std::cout << "Socket closed" << std::endl;
	return 0;
}
