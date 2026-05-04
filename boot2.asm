; ==================================================
; 32位保护模式引导程序
; 功能：从实模式切换到32位保护模式，显示 "Hello world!"
; 编译：nasm -f bin boot.asm -o boot.bin
; 运行：qemu-system-x86_64 boot.bin
; ==================================================

bits 16                      ; 16位实模式代码（CPU 启动时处于实模式）
org 0x7c00                   ; BIOS 将引导扇区加载到 0x7c00

; ========== 第一阶段：实模式 ==========
boot:
    ; 启用 A20 地址线（允许访问 1MB 以上内存）
    mov ax, 0x2401           ; AH=0x24（启用 A20），AL=0x01（子功能）
    int 0x15                 ; 调用 BIOS 中断，启用 A20 地址线

    ; 设置视频模式
    mov ax, 0x3              ; AH=0x00（设置视频模式），AL=0x03（80x25 彩色文本模式）
    int 0x10                 ; 调用 BIOS 中断，设置文本模式

    cli                      ; 关中断（保护模式下中断机制不同）

    ; 加载全局描述符表（GDT）
    lgdt [gdt_pointer]       ; 将 GDT 指针加载到 GDTR 寄存器
							 ; 告诉它 GDT 的地址和大小

    ; 启用保护模式（设置 CR0 寄存器的 PE 位）
    mov eax, cr0             ; 读取控制寄存器 CR0
    or eax, 0x1              ; 将 PE 位（位0）设为 1（Protection Enable）
    mov cr0, eax             ; 写回 CR0，进入保护模式

    ; 远跳转到 32 位代码段（刷新流水线，CPU 重新读取指令时，按32位模式解码）
    jmp CODE_SEG:boot2       ; 跳转到 CODE_SEG 段选择子指向的 boot2 标签

; ========== 全局描述符表（GDT）==========
; GDT 定义了内存段的属性：基址、界限、权限等
gdt_start:
    dq 0x0                   ; 第1个描述符：空描述符（必须为0）

; 代码段描述符
gdt_code:
    dw 0xFFFF                ; 段界限（低16位）：0xFFFF
    dw 0x0                   ; 基址（低16位）：0x0000
    db 0x0                   ; 基址（中8位）：0x00
    db 10011010b             ; 访问权限字节（Present=1, DPL=00, Type=1, Code=1, Conforming=0, Readable=1, Accessed=0）
                             ; = 0x9A
    db 11001111b             ; 标志位 + 段界限（高4位）：标志（4位）+ 界限高4位
                             ; = 0xCF（粒度4KB，32位段）
    db 0x0                   ; 基址（高8位）：0x00

; 数据段描述符
gdt_data:
    dw 0xFFFF                ; 段界限（低16位）：0xFFFF
    dw 0x0                   ; 基址（低16位）：0x0000
    db 0x0                   ; 基址（中8位）：0x00
    db 10010010b             ; 访问权限字节（Present=1, DPL=00, Type=1, Code=0, Expand down=0, Writable=1, Accessed=0）
                             ; = 0x92
    db 11001111b             ; 标志位 + 段界限（高4位）：0xCF
    db 0x0                   ; 基址（高8位）：0x00

gdt_end:                     ; GDT 结束标签

; GDT 指针结构（用于 lgdt 指令）
gdt_pointer:
    dw gdt_end - gdt_start - 1   ; GDT 界限（大小减1）
    dd gdt_start             	 ; GDT 基地址

; 段选择子常量
CODE_SEG equ gdt_code - gdt_start    ; 代码段选择子（0x08）
DATA_SEG equ gdt_data - gdt_start    ; 数据段选择子（0x10）

; ========== 第二阶段：32位保护模式 ==========
bits 32                      ; 现在生成32位代码

boot2:
    ; 设置数据段寄存器
    mov ax, DATA_SEG         ; 加载数据段选择子
    mov ds, ax               ; 数据段
    mov es, ax               ; 附加段
    mov fs, ax               ; 附加段
    mov gs, ax               ; 附加段
    mov ss, ax               ; 堆栈段

    ; 显示字符串（直接写入显存）
    mov esi, hello           ; ESI 指向 hello 字符串
    mov ebx, 0xb8000         ; EBX 指向显存起始地址（文本模式）
                             ; 0xb8000 是彩色文本模式显存地址

.loop:
    lodsb                    ; 加载一个字节到 AL，ESI++
    or al, al                ; 检查是否为 0（字符串结束符）
    jz halt                  ; 如果是0，跳转到 halt

    or eax, 0x0100           ; 设置属性字节（高8位=0x01，蓝色前景）
                             ; EAX = AL（字符）+ 0x0100（属性）
    mov word [ebx], ax       ; 将字符和属性写入显存
    add ebx, 2               ; 显存指针移动2字节（字符+属性）

    jmp .loop                ; 继续下一个字符

halt:
    cli                      ; 关中断
    hlt                      ; 暂停 CPU

hello: 
    db "Hello world!", 0     ; 要显示的字符串

; ========== 引导扇区填充 ==========
times 510 - ($ - $$) db 0    ; 填充到 510 字节
dw 0xaa55                    ; 引导扇区魔数（0x55, 0xAA）