;主引导程序 
;------------------------------------------------------
; 在屏幕上打印字符串 "1 MBR", 背景色为黑色，前景色为绿色
;------------------------------------------------------

SECTION MBR vstart=0x7c00         
    mov ax, cs      
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov sp, 0x7c00

;------------------------------------------------------
;INT 0x10
;BIOS 的 Video Service, 提供了屏幕及显示器所提供的服务程序
;该程序提供多种显示功能，功能号置于AH寄存器，下面列举本代码用到的
;0x06: 初始化和上卷窗口
;0x03: 获取当前光标位置
;0x13: 显示字符串
;具体参数和返回值见下方
;------------------------------------------------------

;清屏，利用0x06号功能，上卷全部行，则可清屏。
;------------------------------------------------------
;INT 0x10   功能号:0x06	   功能描述: 上卷窗口
;------------------------------------------------------
;输入：
;   AH = 功能号 0x06
;   AL = 上卷的行数(如果为0,表示全部)
;   BH = 上卷行属性
;   (CL,CH) = 窗口左上角的(X,Y)位置
;   (DL,DH) = 窗口右下角的(X,Y)位置
;输出：
;   无
    mov ax, 0x600   ; 或者 mov al, 0x0
                    ; mov ah, 0x6
    mov bx, 0x700
    mov cx, 0       ; 左上角: (0, 0)
    mov dx, 0x184f  ; 右下角: (80,25),
                    ; VGA 文本模式中,一行只能容纳 80 个字符, 共 25 行。
                    ; 下标从 0 开始,所以0x18=24,0x4f=79
    int 0x10        ; int 0x10

;获取当前光标位置, 在光标位置处打印字符.
;------------------------------------------------------
;INT 0x10   功能号:0x03	   功能描述: 获取当前光标位置
;------------------------------------------------------
;输入：
;   AH = 功能号 0x03
;   BH = 待获取光标的页号, 可简单理解一页就是一屏
;输出：
;   (CL,CH) = (光标结束行, 光标开始行)
;   (DL,DH) = (光标所在列号, 光标所在行号)
    mov ah, 3
    mov bh, 0
    int 0x10


;打印字符串
;------------------------------------------------------
;INT 0x10   功能号:0x13	   功能描述: 打印字符串
;------------------------------------------------------
;输入：
;   es:bp 为串首地址
;   CX = 串长度,不包括结束符0的字符个数
;   AH = 功能号 0x13
;   AL = 写字符方式: 光标跟随移动
;   BH = 存储要显示的页号, 此处是第0页
;   BL = 字符属性, 属性黑底绿字(bl = 02h)
;输出：
;   无
    mov ax, message 
    mov bp, ax		; es此时同cs一致，开头时已经为sreg初始化

    ; 光标位置要用到 dx 寄存器中内容, cx 中的光标位置可忽略
    mov cx, 5       ; len("1 MBR") == 5
    mov ax, 0x1301
    mov bx, 0x2
    int 0x10


    jmp $		    ; dead loop


; 填充扇区剩余空间，并设置魔数
    message db "1 MBR"
    times 510-($-$$) db 0
    db 0x55,0xaa