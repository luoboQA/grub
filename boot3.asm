; ==================================================
; 多扇区引导程序
; 功能：从硬盘读取超过512字节的代码并执行
; ==================================================

bits 16                      ; 16位实模式
org 0x7c00                   ; BIOS 加载地址

boot:
    ; ===== 启用 A20 地址线（访问 1MB+ 内存）=====
    mov ax, 0x2401
    int 0x15

    ; ===== 设置视频模式（80x25 彩色文本）=====
    mov ax, 0x3
    int 0x10

    ; ===== 保存启动盘号 =====
    ; BIOS 会把启动盘号（0=软盘，0x80=硬盘）放到 DL
    mov [disk], dl           ; 保存到变量 disk

    ; ===== 使用 BIOS 中断 0x13 读取硬盘 =====
    mov ah, 0x2              ; 功能号：读扇区
    mov al, 1                ; 读取 1 个扇区（512字节）
    mov ch, 0                ; 柱面号：0
    mov dh, 0                ; 磁头号：0
    mov cl, 2                ; 扇区号：2（第2个扇区，跳过引导扇区）
    mov dl, [disk]           ; 驱动器号：启动盘
    mov bx, copy_target      ; 目标地址：copy_target 标签
    int 0x13                 ; 调用 BIOS 磁盘服务

    ; ===== 进入保护模式 =====
    cli                      ; 关中断
    lgdt [gdt_pointer]       ; 加载 GDT
    mov eax, cr0             ; 读取 CR0
    or eax, 0x1              ; 设置 PE=1（保护模式使能）
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
    db 10011010b             ; 权限：可读、可执行
    db 11001111b             ; 标志：4KB粒度、32位段
    db 0x0                   ; 基址高8位

gdt_data:                    ; 数据段描述符
    dw 0xFFFF
    dw 0x0
    db 0x0
    db 10010010b             ; 权限：可读写
    db 11001111b
    db 0x0

gdt_end:

gdt_pointer:                 ; GDT 指针（用于 lgdt）
    dw gdt_end - gdt_start-1   ; GDT 界限
    dd gdt_start             ; GDT 基址

disk:                        ; 保存启动盘号
    db 0x0

CODE_SEG equ gdt_code - gdt_start    ; 0x08
DATA_SEG equ gdt_data - gdt_start    ; 0x10

; 填充引导扇区（512字节）
times 510 - ($ - $$) db 0
dw 0xaa55                    ; 引导魔数

; ==================================================
; 这部分代码被读取到 copy_target 地址
; ==================================================
copy_target:                 ; 第2个扇区将被读到这个地址
bits 32                      ; 32位保护模式代码

hello: db "Hello more than 512 bytes world!!", 0

boot2:
    mov esi, hello           ; ESI = 字符串地址
    mov ebx, 0xb8000         ; EBX = 显存地址

.loop:
    lodsb                    ; AL = [ESI], ESI++
    or al, al                ; 检查是否为 0
    jz halt                  ; 是0则结束

    or eax, 0x0F00           ; 设置属性：0x0F = 亮白色
    mov word [ebx], ax       ; 写入显存（字符+属性）
    add ebx, 2               ; 下一个字符位置

    jmp .loop

halt:
    cli
    hlt

; 填充到 1024 字节（第2扇区）
times 1024 - ($ - $$) db 0