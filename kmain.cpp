extern "C" void kmain()  // extern "C" 防止 C++ 名称修饰（name mangling）
                         // 让汇编代码能用 call kmain 直接调用
{	
    const short color = 0x0F00;        // 颜色属性：0x0F = 亮白色前景
                                       // 0x0F00 是短整型，高8位是颜色
    
    const char* hello = "Hello cpp world!";  // 字符串（每个字符1字节）
    
    short* vga = (short*)0xb8000;      // 显存地址（80x25 文本模式）
                                       // short* 表示每个单元占2字节：
                                       // [字符][属性]
    
    for (int i = 0; i < 16; ++i)       // 循环16次（"Hello cpp world!" 长度）
        vga[i+80] = color | hello[i];  // 从第2行开始显示（跳过第一行）
}