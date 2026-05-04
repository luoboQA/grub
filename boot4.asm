; ==================================================
; 多扇区引导程序 + 内核加载器
; 功能：读取多个扇区，进入保护模式，然后调用 C 语言内核
; 编译：nasm -f elf32 boot4.asm -o boot4.o
; 编译并链接：g++ -m32 -fno-pic -fno-pie kmain.cpp boot4.o -o kernel.bin -nostdlib \
-ffreestanding -std=c++11 -mno-red-zone -fno-exceptions -fno-rtti \
-Wall -Wextra -T linker.ld
; 运行：qemu-system-x86_64-fda kernel.bin
; ==================================================

section .boot
bits 16
global boot

boot:
    ; ===== 启用 A20 地址线（访问 1MB+ 内存）=====
    mov ax, 0x2401
    int 0x15

    ; ===== 设置视频模式（80x25 彩色文本）=====
    mov ax, 0x3
    int 0x10

    ; ===== 保存启动盘号 =====
    ; BIOS 把启动设备号放在 DL，保存起来
    mov [disk], dl

    ; ===== 使用 BIOS 中断 0x13 读取硬盘 =====
    mov ah, 0x2              ; 功能号：读扇区
    mov al, 6                ; 读取 6 个扇区（6 × 512 = 3072 字节）
    mov ch, 0                ; 柱面号：0
    mov dh, 0                ; 磁头号：0
    mov cl, 2                ; 扇区号：2（从第2个扇区开始读）
    mov dl, [disk]           ; 驱动器号：启动盘
    mov bx, copy_target      ; 目标地址：copy_target 标签
    int 0x13                 ; 调用 BIOS 磁盘服务

    ; ===== 进入保护模式 =====
    cli                      ; 关中断
    lgdt [gdt_pointer]       ; 加载全局描述符表
    mov eax, cr0             ; 读取控制寄存器 CR0
    or eax, 0x1              ; 设置 PE 位（保护模式使能）
    mov cr0, eax             ; 写回 CR0，进入保护模式

    ; ===== 设置数据段寄存器 =====
    mov ax, DATA_SEG         ; 数据段选择子（0x10）
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax

    ; ===== 远跳转到保护模式代码 =====
    jmp CODE_SEG:boot2       ; CS = CODE_SEG(0x08), EIP = boot2

; ========== 全局描述符表（GDT）==========
gdt_start:
    dq 0x0                   ; 空描述符（必须）

gdt_code:                    ; 代码段描述符
    dw 0xFFFF                ; 段界限低16位
    dw 0x0                   ; 基址低16位
    db 0x0                   ; 基址中8位
    db 10011010b             ; 访问权限：可读、可执行
    db 11001111b             ; 标志：4KB粒度、32位段
    db 0x0                   ; 基址高8位

gdt_data:                    ; 数据段描述符
    dw 0xFFFF
    dw 0x0
    db 0x0
    db 10010010b             ; 访问权限：可读写
    db 11001111b
    db 0x0

gdt_end:

gdt_pointer:                 ; GDT 指针（用于 lgdt 指令）
    dw gdt_end - gdt_start   ; GDT 界限（大小减1）
    dd gdt_start             ; GDT 基址

disk:                        ; 保存启动盘号的变量
    db 0x0

CODE_SEG equ gdt_code - gdt_start    ; 代码段选择子 = 0x08
DATA_SEG equ gdt_data - gdt_start    ; 数据段选择子 = 0x10

; 填充引导扇区到 510 字节，最后加上引导魔数
times 510 - ($ - $$) db 0
dw 0xaa55                    ; 引导扇区魔数（必须）

; ==================================================
; 以下代码被 BIOS 中断 0x13 读取到内存（第2-7扇区）
; ==================================================
copy_target:
bits 32                      ; 进入保护模式后执行

hello: db "Hello more than 512 bytes world!!", 0

boot2:
    ; ===== 在保护模式下显示字符串 =====
    mov esi, hello           ; ESI = 字符串地址
    mov ebx, 0xb8000         ; EBX = 显存地址（80x25 文本模式）

.loop:
    lodsb                    ; AL = [ESI], ESI++
    or al, al                ; 检查是否为 0（字符串结束符）
    jz halt                  ; 如果是，跳转到 halt

    or eax, 0x0F00           ; 设置属性字节：0x0F = 亮白色前景
    mov word [ebx], ax       ; 写入显存（字符 + 属性）
    add ebx, 2               ; 移动到下一个字符位置
    jmp .loop

halt:
    ; ===== 设置内核栈并跳转到 C 语言内核 =====
    mov esp, kernel_stack_top    ; 设置栈指针
    extern kmain                 ; 声明外部 C 函数
    call kmain                   ; 调用内核主函数
    
    cli                      ; 关中断（不应该执行到这里）
    hlt                      ; 暂停 CPU

; ========== 内核栈空间（BSS 段）==========
section .bss
align 4                      ; 4字节对齐
kernel_stack_bottom: equ $   ; 栈底标记
    resb 16384               ; 预留 16KB 栈空间
kernel_stack_top:            ; 栈顶（栈向下增长，esp 指向这里）