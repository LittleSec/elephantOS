%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR
jmp loader_start

;构建gdt及其内部的描述符
;gdt只是一片内存区域, 每8字节一个表项(即段描述符), 定义方法不唯一, 这里拆分成高低4字节分别定义
;注意该文件编译后从头到尾地址是从小到大, 因此先定义低4字节后定义高4字节
;第0个段描述符无用
GDT_BASE:         dd  0x00000000 
                  dd  0x00000000

CODE_DESC:        dd  0x0000FFFF 
                  dd  DESC_CODE_HIGH4

DATA_STACK_DESC:  dd  0x0000FFFF
                  dd  DESC_DATA_HIGH4

;显存段描述符
;用于文本模式显示适配器的内存地址是0xb8000~0xbffff
VIDEO_DESC:       dd  0x80000007         ;limit=(0xbffff-0xb8000)/4k=0x7
                  dd  DESC_VIDEO_HIGH4   ;此时dpl已改为0

GDT_SIZE    equ   $ - GDT_BASE
GDT_LIMIT   equ   GDT_SIZE - 1 
times 60 dq 0 ;此处预留60个描述符的slot, 日后方便扩展, dq,define qual-word, 4words=8bytes

SELECTOR_CODE  equ (0x0001<<3) + TI_GDT + RPL0  ; 相当于(CODE_DESC - GDT_BASE)/8 + TI_GDT + RPL0
SELECTOR_DATA  equ (0x0002<<3) + TI_GDT + RPL0  ; 同上
SELECTOR_VIDEO equ (0x0003<<3) + TI_GDT + RPL0  ; 同上 

;以下是定义gdt的指针，前2字节是gdt界限，后4字节是gdt起始地址
gdt_ptr   dw  GDT_LIMIT 
          dd  GDT_BASE
loadermsg db  '2 loader in real.'



loader_start:
;------------------------------------------------------
;INT 0x10   功能号:0x13    功能描述: 打印字符串
;------------------------------------------------------
;输入：
;   es:bp 为串首地址
;   AH = 功能号 0x13
;   AL ＝ 显示输出方式
;     0 字符串中只含显示字符, 其显示属性在BL中。显示后, 光标位置不变
;     1 字符串中只含显示字符, 其显示属性在BL中。显示后, 光标位置改变
;     2 字符串中含显示字符和显示属性。显示后, 光标位置不变
;     3 字符串中含显示字符和显示属性。显示后, 光标位置改变
;   BH = 存储要显示的页号, 此处是第0页
;   BL = 字符属性, 属性蓝底粉红字(bl = 1fh)
;   CX = 串长度,不包括结束符0的字符个数
;   (DL,DH) = 窗口右下角的(X,Y)位置
;输出：
;   无
    mov sp, LOADER_BASE_ADDR
    mov bp, loadermsg
    mov ax, 0x1301
    mov bx, 0x001f
    mov cx, 17
    mov dx, 0x1800
    int 0x10


;---------- 准备进入保护模式 ----------
;1. open A20
;2. load gdt
;3. set pe=1 in cr0

;---------- 1. open A20 ------------
    in al, 0x92
    or al, 0000_0010B
    out 0x92, al

;---------- 2. load gdt ------------
    lgdt [gdt_ptr]


;---------- 3. set pe=1 in cr0 -----
    mov eax, cr0
    or eax, 0x1
    mov cr0, eax

;可以尝试注释这句有什么错误表现, 逻辑上去掉没问题, 但实际上不行
    jmp dword SELECTOR_CODE:p_mode_start  ;cpu在遇到无条件jmp会刷新流水线, 避免分支预测的影响
                                          ;因为无条件jmp会导致之前做的预测失效
                                          ;至于为啥要刷新是因为下面的是32位的指令, 这条是16位的指令,
                                          ;在实模式下译码的时候会按照16位指令格式译码

;---------- 以下代码已经进入保护模式 ---
[bits 32]
p_mode_start:
    mov ax, SELECTOR_DATA
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, LOADER_STACK_TOP
    mov ax, SELECTOR_VIDEO
    mov gs, ax

    mov byte [gs:160], 'P'  ;80*2=160, 在第二行输出'P', 低字节是ASCII, 高字节是attr, 默认黑底白字

    jmp $
