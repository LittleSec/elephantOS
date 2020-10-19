%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR
;mbr.S 的 jmp LOADER_BASE_ADDR 直接改成 jmp LOADER_BASE_ADDR+0x300
; jmp loader_start ; 该指令会占三个字节，要注释才能使得 loader_start 在0x300 偏移

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

; total_mem_bytes用于保存内存容量, 以字节为单位, 此位置比较好记。
; 当前偏移loader.bin文件头0x200字节(4个段描述符+60个slot,都是8字节一个),
; loader.bin的加载地址是0x900,
; 故total_mem_bytes内存中的地址是0xb00.将来在内核中咱们会引用此地址
total_mem_bytes dd 0


;以下是定义gdt的指针，前2字节是gdt界限，后4字节是gdt起始地址
gdt_ptr   dw  GDT_LIMIT 
          dd  GDT_BASE

; 人工对齐:
; total_mem_bytes4字节 + gdt_ptr6字节 + ards_buf244字节 + ards_nr2, 共256字节
ards_buf times 244 db 0
ards_nr dw 0    ;用于记录ards结构体数量


;------------------------------------------------------
;INT 0x15
;BIOS中断，获取物理内存用量
;具体参数和返回值见下方
;经过构造 total_mem_bytes 在 0xb00 处, 
;故:
;1. 修改 bochsrc.disk 中 megs 的值
;2. 在调试器中打印 0xb00 处的内容可以验证(eg. xp 0xb00)
;------------------------------------------------------

loader_start:
;------------------------------------------------------
;INT 0x15   功能号:0xE820    功能描述: 遍历主机上的全部内存
;------------------------------------------------------
;输入：
;   ES:DI = 指向 ASDR 缓冲区
;   EAX = 功能号 0xE820
;   EBX = ARDS 后续值, 第一次调用设为0, 每次中断返回 BIOS 会自己更新
;   ECX = ARDS 结构的字节大小
;   EDX = 固定签名标记 0x534D4150(ASCII: "SMAP")
;输出：
;   CF = 0 succ, 1 fail
;   EAX = 0x534D4150(ASCII: "SMAP")
;   ECX = BIOS 写入 ES:DI 所指向的 ARDS 结构的字节数，最小写入 20 字节
;   EBX = 后续值
    xor ebx, ebx
    mov edx, 0x534d4150
    mov di, ards_buf
.e820_mem_get_loop:                 ;循环获取每个 ARDS 内存范围描述结构
    mov eax, 0x0000e820             ;执行 int 0x15 后, eax值变为0x534d4150,所以每次执行 int 前都要更新为子功能号。
    mov ecx, 20                     ;ARDS地址范围描述符结构大小是20字节
    int 0x15
    jc .e820_failed_so_try_e801     ;若cf位为1则有错误发生，尝试0xe801子功能
    add di, cx                      ;使di增加20字节指向缓冲区中新的ARDS结构位置
    inc word [ards_nr]              ;记录ARDS数量
    cmp ebx, 0                      ;若ebx为0且cf不为1,这说明ards全部返回，当前已是最后一个
    jnz .e820_mem_get_loop

;在所有ards结构中，找出(base_add_low + length_low)的最大值，即内存的容量。
    mov cx, [ards_nr]               ;遍历每一个ARDS结构体,循环次数是ARDS的数量
    mov ebx, ards_buf 
    xor edx, edx                    ;edx为最大的内存容量,在此先清0
.find_max_mem_area:                 ;无须判断type是否为1,最大的内存块一定是可被使用
    mov eax, [ebx]                  ;base_add_low
    add eax, [ebx+8]                ;length_low
    add ebx, 20                     ;指向缓冲区中下一个ARDS结构
    cmp edx, eax                    ;冒泡排序，找出最大,edx寄存器始终是最大的内存容量
    jge .next_ards
    mov edx, eax                    ;edx为总内存大小
.next_ards:
    loop .find_max_mem_area
    jmp .mem_get_ok


;------------------------------------------------------
;INT 0x15   功能号:0xE810    功能描述: 获取内存大小,最大支持4G
;------------------------------------------------------
;输入：
;   AX = 功能号 0xE810
;输出：
;   CF = 0 succ, 1 fail
;   AX = 以 1KB 为单位, 只显示 15MB 以下的内存容量, 故最大值为 0x3c00(*1KB=15MB)
;   BX = 以 64KB 为单位, 显示内容空间中 16MB~4GB 中连续的单位数量, 即内存大小为 BX*64KB
;   CX = 同 AX (可忽略, 说明书上也不明确与AX的区别)
;   DX = 同 BX (同上)
.e820_failed_so_try_e801:
    mov ax, 0xe801
    int 0x15
    jc .e801_failed_so_try88   ;若当前e801方法失败, 就尝试0x88方法

;1 先算出低15M的内存,ax和cx中是以KB为单位的内存数量,将其转换为以byte为单位
    mov cx, 0x400           ;cx和ax值一样,cx用做乘数,1kb=0x400 Bytes
    mul cx 
    shl edx, 16
    and eax, 0x0000FFFF
    or edx, eax
    add edx, 0x100000       ;ax只是15MB, 故要加1MB
    mov esi, edx            ;先把低15MB的内存容量存入esi寄存器备份

;2 再将16MB以上的内存转换为byte为单位,寄存器bx和dx中是以64KB为单位的内存数量
    xor eax, eax
    mov ax, bx
    mov ecx, 0x10000    ;64KB=0x10000 Bytes
    mul ecx             ;32位乘法,默认的被乘数是eax,积为64位,高32位存入edx,低32位存入eax.
    add esi, eax        ;由于此方法只能测出4G以内的内存,故32位eax足够了,edx肯定为0,只加eax便可
    mov edx, esi        ;edx为总内存大小
    jmp .mem_get_ok


;------------------------------------------------------
;INT 0x15   功能号:0x88    功能描述: 获取内存大小,只能获取64M之内
;------------------------------------------------------
;输入：
;   AH = 功能号 0xE810
;输出：
;   CF = 0 succ, 1 fail
;   AX = 以 1KB 为单位, 内存空间在 1MB 之上的连续单位数量, 不包括低端 1MB 内存, 故内存大小=AX*1KB+1MB
.e801_failed_so_try88: 
   mov  ah, 0x88
   int  0x15
   jc .error_hlt
   and eax, 0x0000FFFF
      
   ;16位乘法，被乘数是ax,积为32位.积的高16位在dx中，积的低16位在ax中
   mov cx, 0x400        ;1kb = 0x400 Bytes
   mul cx
   shl edx, 16          ;把dx移到高16位
   or edx, eax          ;把积的低16位组合到edx,为32位的积
   add edx, 0x100000    ;0x88子功能只会返回1MB以上的内存,故实际内存大小要加上1MB


.mem_get_ok:
   mov [total_mem_bytes], edx    ;将内存换为byte单位后存入total_mem_bytes处。


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

.error_hlt:      ;出错则挂起
   hlt

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
