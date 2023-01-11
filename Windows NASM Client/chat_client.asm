bits 32

global start        

extern exit, printf, scanf, WSAStartup, WSACleanup, socket, closesocket, connect, send, recv, inet_addr, htons, CreateThread, ExitThread, CloseHandle, WaitForSingleObject
import exit msvcrt.dll
import printf msvcrt.dll
import scanf msvcrt.dll

import WSAStartup Ws2_32.dll
import WSACleanup Ws2_32.dll
import socket Ws2_32.dll
import closesocket Ws2_32.dll
import connect Ws2_32.dll
import send Ws2_32.dll
import recv Ws2_32.dll

import inet_addr Ws2_32.dll
import htons Ws2_32.dll

import CreateThread Kernel32.dll
import ExitThread Kernel32.dll
import CloseHandle Kernel32.dll
import WaitForSingleObject Kernel32.dll

segment data use32 class=data
    ; STRINGS
    welcome_msg db "TCP client", 10, 0
    quit_msg db "INFO: Quit", 10, 0

    WSAStartup_error db "ERROR: WSAStartup()", 10, 0
    socket_error db "ERROR: socket()", 10, 0
    connect_error db "ERROR: connect()", 10, 0
    send_error db "ERROR: send()", 10, 0
    recv_error db "ERROR: recv()", 10, 0
    thread_error db "ERROR: CreateThread()", 10, 0
    
    buffer_print_format db "%s", 10, 0
    
    ; CONSTANTS
    SERVER_IP db "192.168.0.250", 0
    SERVER_PORT dw 7777
    BUFFER_LEN equ 255      ; 1 off because we add the null char ourselves

    WSA_VERSION dw 0202h    ; MAKEWORD(2, 2)
    AF_INET equ 2
    SOCK_STREAM equ 1
    IPPROTO_TCP equ 6
    
    INVALID_SOCKET equ ~0   ; UNSIGNED
    SOCKET_ERROR equ -1     ; SIGNED
    
    INFINITE equ 0FFFFFFFFh
    NULL equ 0

    ; BOOLS
    wsaStarted db 0
    sockCreated db 0
    quitThreads db 0

    ; WINAPI SOCKET
    SIZEOF_WSADATA equ 400
    wsaData resb SIZEOF_WSADATA
    SIZEOF_SOCKADDR equ 16
    sockAddr resb SIZEOF_SOCKADDR
    
    ; HANDLES
    sockHandle resd 1
    inputThreadHandle resd 1
    recvThreadHandle resd 1
    
    ; BUFFERS
    sendBuff times (BUFFER_LEN+1) db 0
    sendLen dd 0
    
    recvBuff times (BUFFER_LEN+1) db 0
    recvLen dd 0
    
    ; READING
    readBuff_prompt db "", 0
    readBuff_format db "%s", 0
    readBuff times (BUFFER_LEN+1) db 0
    
    userName_separator db ": ", 0
        
    userName_prompt db "Name: ", 0
    userName_format db "%s", 0
    userName times (BUFFER_LEN+1) db 0
    
segment code use32 class=code
    strlen:
        mov esi, [esp+4]                    ; load function parameter
        xor ecx, ecx                        ; zero counter
        
        cld                                 ; clear direction flag
        strlen_loop:
            lodsb                           ; load into AL
            cmp al, byte 0                  ; check if current char is the null char
            je return_strlen                ; if equal, stop counting
            
            inc ecx                         ; increase counter
        jmp strlen_loop
        
        return_strlen:
        mov eax, ecx                        ; eax = ecx
        ret                                 ; return eax
    
    copy_to_sendBuff:
        mov esi, [esp+4]                    ; load function parameter

        cmp edi, BUFFER_LEN                 ; >= BUFFER_LEN?
        jge return_copy_to_sendBuff         ; stop copying to not overwrite memory
    
        cld                                 ; clear direction flag
        copy_loop:
            lodsb                           ; load into AL
            
            cmp al, byte 0                  ; check if current char is the null char
            je return_copy_to_sendBuff      ; if equal, stop copying
            
            ;stosb
            mov [sendBuff+edi], byte al     ; copy character
            inc edi                         ; increase character index
            
            cmp edi, BUFFER_LEN             ; >= BUFFER_LEN?
            jge return_copy_to_sendBuff     ; stop copying to not overwrite memory
        jmp copy_loop
        
        return_copy_to_sendBuff:
        ret
    
    input_thread:
        input_loop:
            cmp [quitThreads], byte 1       ; == 1?
            je input_thread_return          ; true, thread should exit
        
            ; read message from console
            push dword readBuff_prompt      ; readBuff_prompt
            call [printf]                   ; printf(readBuff_prompt)
            add esp, 4                      ; clean up stack, 1 dword
            
            push dword readBuff             ; readBuff
            push dword readBuff_format      ; readBuff_format
            call [scanf]                    ; scanf(readBuff_format, readBuff)
            add esp, 4 * 2                  ; clean up stack, 2 dwords
            
            ; concatenate strings
            mov edi, dword 0                ; initialize length with 0
            push dword userName             ; userName
            call copy_to_sendBuff           ; copy userName to sendBuff
            
            push dword userName_separator   ; userName_separator
            call copy_to_sendBuff           ; copy userName_separator to sendBuff
            
            push dword readBuff             ; readBuff
            call copy_to_sendBuff           ; copy readBuff to sendBuff
            
            mov [sendBuff+edi], byte 0      ; add null character to new string
            mov dword [sendLen], edi        ; save the length of the new string
            
            ; send previously read message
            push dword 0                    ; flags
            push dword [sendLen]            ; sizeof(sendBuff)
            push dword sendBuff             ; sendBuff
            push dword [sockHandle]         ; sockHandle
            call [send]                     ; send(sockHandle, sendBuff, sizeof(sendBuff), 0)
            cmp eax, SOCKET_ERROR           ; != SOCKET_ERROR?
        jne input_loop                      ; true, jump to start of loop
        
        push dword send_error               ; else, print error
        call [printf]                       ; printf(send_error)
        add esp, 4                          ; clean up stack, 1 dword
        
        input_thread_return:
        mov [quitThreads], byte 1           ; mark threads for stopping
        
        push dword 0                        ; 0
        call [ExitThread]                   ; ExitThread(0)
        
    recv_thread:
        recv_loop:
            cmp [quitThreads], byte 1       ; == 1?
            je recv_thread_return           ; true, thread should exit
            
            ; recv
            push dword 0                    ; flags
            push dword BUFFER_LEN           ; BUFFER_LEN
            push dword recvBuff             ; recvBuff
            push dword [sockHandle]         ; sockHandle
            call [recv]                     ; recv(sockHandle, recvBuff, BUFFER_LEN, 0)
            cmp eax, dword 0                ; <= 0?
            jle recv_stop                   ; true, jump to handle connection closed/error
            
            ; add null char to received string
            mov edi, eax
            mov [recvBuff+edi], byte 0
            mov dword [recvLen], eax
            
            push dword recvBuff             ; recvBuff
            push dword buffer_print_format  ; buffer_print_format
            call [printf]                   ; printf(buffer_print_format, recvBuff)
            add esp, 4 * 2                  ; clean up stack, 2 dwords
        jmp recv_loop
        
        recv_stop:
        cmp eax, dword 0                    ; == 0?
        je recv_thread_return               ; true (connection closed), don't print error
        push dword recv_error               ; else, print error
        call [printf]                       ; printf(recv_error)
        add esp, 4                          ; clean up stack, 1 dword

        recv_thread_return:                 ; end thread
        mov [quitThreads], byte 1           ; mark threads for stopping
        
        push dword 0                        ; 0
        call [ExitThread]                   ; ExitThread(0)
        
    start:
        ; printf and scanf use the cdecl calling convention
        ; so the stack must be cleaned up after every call
        ; the rest of the imported functions use the stdcall
        ; calling convention so stack management is not needed
        
        ; show welcome message
        push dword welcome_msg          ; welcome_msg
        call [printf]                   ; printf(welcome_msg)
        add esp, 4                      ; clean up stack, 1 dword
        
        ; read name from console
        push dword userName_prompt      ; userName_prompt
        call [printf]                   ; printf(userName_prompt)
        add esp, 4                      ; clean up stack, 1 dword
        
        push dword userName             ; userName
        push dword userName_format      ; userName_format
        call [scanf]                    ; scanf(userName_format, userName)
        add esp, 4 * 2                  ; clean up stack, 2 dwords
        
        ; WSAStartup
        push dword wsaData              ; wsaData
        push dword WSA_VERSION          ; WSA_VERSION
        call [WSAStartup]               ; WSAStartup(WSA_VERSION, wsaData)
        cmp eax, dword 0                ; == 0?
        je socket_create                ; true, jump to create socket
        push dword WSAStartup_error     ; else, print error
        call [printf]                   ; printf(WSAStartup_error)
        add esp, 4                      ; clean up stack, 1 dword
        jmp cleanup                     ; jump to program cleanup
        
        socket_create:
        mov [wsaStarted], byte 1        ; WSAStartup success, cleanup will be required
        ; socket
        push dword IPPROTO_TCP          ; IPPROTO_TCP
        push dword SOCK_STREAM          ; SOCK_STREAM
        push dword AF_INET              ; AF_INET
        call [socket]                   ; socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        mov [sockHandle], eax           ; save handle
        cmp eax, INVALID_SOCKET         ; != INVALID_SOCKET?
        jne socket_connect              ; true, jump to create connection
        push dword socket_error         ; else, print error
        call [printf]                   ; printf(socket_error)
        add esp, 4                      ; clean up stack, 1 dword
        jmp cleanup                     ; jump to program cleanup
        
        socket_connect:
        mov [sockCreated], byte 1       ; socket success, cleanup will be required
        ; create address
        mov [sockAddr], dword AF_INET   ; sockAddr[, , AF_INET]; short sin_family
        push dword [SERVER_PORT]        ; SERVER_PORT
        call [htons]                    ; htons(SERVER_PORT); unsigned short sin_port
        mov [sockAddr+2], word ax       ; sockAddr[, htons(SERVER_PORT), AF_INET]
        push dword SERVER_IP            ; SERVER_IP
        call [inet_addr]                ; inet_addr(SERVER_IP); unsigned long s_addr
        mov [sockAddr+4], dword eax     ; sockAddr[inet_addr(SERVER_IP), htons(SERVER_PORT), AF_INET]
        ; connect
        push dword SIZEOF_SOCKADDR      ; sizeof(sockAddr)
        push dword sockAddr             ; sockAddr
        push dword [sockHandle]         ; sockHandle
        call [connect]                  ; connect(sockHandle, sockAddr, sizeof(sockAddr))
        cmp eax, SOCKET_ERROR           ; != SOCKET_ERROR?
        jne create_input_thread         ; true, jump to create threads
        push dword connect_error        ; else, print error
        call [printf]                   ; printf(connect_error)
        add esp, 4                      ; clean up stack, 1 dword
        jmp cleanup                     ; jump to program cleanup
        
        ; create threads
        create_input_thread:
        push NULL                       ; NULL
        push dword 0                    ; 0
        push NULL                       ; NULL
        push input_thread               ; input_thread
        push dword 0                    ; 0
        push NULL                       ; NULL
        call [CreateThread]             ; CreateThread(NULL, 0, input_thread, NULL, 0, NULL)
        mov [inputThreadHandle], eax    ; save handle
        
        cmp eax, NULL                   ; == NULL?
        jne create_recv_thread          ; false, jump to create other thread
        
        push dword thread_error         ; else, print error
        call [printf]                   ; printf(thread_error)
        add esp, 4                      ; clean up stack, 1 dword
        jmp cleanup                     ; jump to program cleanup
        
        create_recv_thread:
        push NULL                       ; NULL
        push dword 0                    ; 0
        push NULL                       ; NULL
        push recv_thread                ; recv_thread
        push dword 0                    ; 0
        push NULL                       ; NULL
        call [CreateThread]             ; CreateThread(NULL, 0, recv_thread, NULL, 0, NULL)
        mov [recvThreadHandle], eax     ; save handle
        
        cmp eax, NULL                   ; == NULL?
        jne join_threads                ; false, jump to join threads
        
        push dword thread_error         ; else, print error
        call [printf]                   ; printf(thread_error)
        add esp, 4                      ; clean up stack, 1 dword

        mov [quitThreads], byte 1       ; mark threads for stopping
        jmp join_input_thread           ; jump to join input thread and program cleanup
        
        ; wait for threads to end
        join_threads:        
        push INFINITE                   ; INFINITE
        push dword [recvThreadHandle]   ; recvThreadHandle
        call [WaitForSingleObject]      ; WaitForSingleObject(recvThreadHandle, INFINITE)
        push dword [recvThreadHandle]   ; recvThreadHandle
        call [CloseHandle]              ; closeHandle(recvThreadHandle)
        
        join_input_thread:
        push INFINITE                   ; INFINITE
        push dword [inputThreadHandle]  ; inputThreadHandle
        call [WaitForSingleObject]      ; WaitForSingleObject(inputThreadHandle, INFINITE)
        push dword [inputThreadHandle]  ; inputThreadHandle
        call [CloseHandle]              ; closeHandle(inputThreadHandle)
        
        cleanup:
        ; closesocket
        cmp [sockCreated], byte 1       ; != 1?
        jne cleanup_wsa                 ; true (invalid socket), don't close the socket
        push dword [sockHandle]         ; else, do
        call [closesocket]              ; closesocket(sockHandle)
        
        cleanup_wsa:
        ; WSACleanup
        cmp [wsaStarted], byte 1        ; != 1?
        jne quit                        ; true (WSAStartup failed), jump to quit
        call [WSACleanup]               ; else, WSACleanup()
        
        push dword quit_msg             ; quit_msg
        call [printf]                   ; printf(quit_msg)
        add esp, 4                      ; clean up stack, 1 dword

        quit:
        push dword 0                    ; 0
        call [exit]                     ; exit(0)
