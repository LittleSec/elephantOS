;主引导程序 
;------------------------------------------------------
; 在屏幕上打印字符串 "1 MBR", 背景色为闪烁绿色，前景色为红色
;------------------------------------------------------

%include "boot.inc"

SECTION MBR vstart=0x7c00         
    mov ax, cs      
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov sp, 0x7c00
; 地址总线中的 0xb8000 ~ 0xbffff 这 32Kb 的内存区域用于文本显示
    mov ax, 0xb800
    mov gs, ax

;------------------------------------------------------
;INT 0x10
;BIOS 的 Video Service, 提供了屏幕及显示器所提供的服务程序
;该程序提供多种显示功能，功能号置于AH寄存器，下面列举本代码用到的
;0x06: 初始化和上卷窗口
;具体参数和返回值见下方
;------------------------------------------------------

;清屏，利用0x06号功能，上卷全部行，则可清屏。
;------------------------------------------------------
;INT 0x10   功能号:0x06    功能描述: 上卷窗口
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

;打印字符串"1 MBR", 绿色背景闪烁，红色前景
    mov byte [gs:0x00], '1'
    mov byte [gs:0x01], 0xA4    ; A表示绿色背景闪烁，4表示前景色为红色

    mov byte [gs:0x02], ' '
    mov byte [gs:0x03], 0xA4

    mov byte [gs:0x04], 'M'
    mov byte [gs:0x05], 0xA4

    mov byte [gs:0x06], 'B'
    mov byte [gs:0x07], 0xA4

    mov byte [gs:0x08], 'R'
    mov byte [gs:0x09], 0xA4

    call sleep_nop                  ;睡眠，以视效果，书中没有，自己加的

    mov eax, LOADER_START_SECTOR    ; 起始扇区lba地址
    mov bx, LOADER_BASE_ADDR        ; 写入的地址
    mov cx, 4                       ; 待读入的扇区数
    call rd_disk_m_16               ; 以下读取程序的起始部分（一个扇区）

    jmp LOADER_BASE_ADDR


;-------------------------------------------------------------------------------
;功能：使用nop睡眠 1s 左右，书中没有，自己加的
;for(i: 0->0xff)
;   for(j: 0->0xffffffff)
;       nop
;-------------------------------------------------------------------------------
sleep_nop:
    mov ecx, 0x1ff
.sleep1:
    mov ebx, ecx
    mov ecx, 0xffffffff
.sleep2:
    nop
    loop .sleep2
    mov ecx, ebx
    loop .sleep1
    ret


;-------------------------------------------------------------------------------
;功能：读取硬盘n个扇区
;输入：
;   eax = LBA扇区号
;   ebx = 将数据写入的内存地址
;   ecx = 读入的扇区数
;-------------------------------------------------------------------------------
rd_disk_m_16:
    mov esi, eax        ;备份eax
    mov di, cx          ;备份cx
;读写硬盘:
;第1步：设置要读取的扇区数
    mov dx, 0x1f2
    mov al, cl
    out dx, al          ;读取的扇区数
    mov eax, esi        ;恢复ax

;第2步：将 LBA 地址存入端口 0x1f3 ~ 0x1f6
    ;LBA 地址 7~0 位写入端口 0x1f3
    mov dx, 0x1f3                       
    out dx, al                          

    ;LBA 地址 15~8 位写入端口 0x1f4
    mov cl, 8
    shr eax, cl
    mov dx, 0x1f4
    out dx, al

    ;LBA 地址 23~16 位写入端口 0x1f5
    shr eax, cl
    mov dx, 0x1f5
    out dx, al

    shr eax, cl
    and al, 0x0f        ;lba 第 24~27 位
    or al, 0xe0         ;设置 7～4 位为1110, 表示lba模式
    mov dx, 0x1f6
    out dx, al

;第3步：向 0x1f7 端口写入读命令 0x20 
    mov dx, 0x1f7
    mov al, 0x20                        
    out dx, al

;第4步：检测硬盘状态
.not_ready:
    ;同一端口，写时表示写入命令字，读时表示读入硬盘状态
    nop
    in al, dx
    and al, 0x88        ;第4位为1表示硬盘控制器已准备好数据传输，第7位为1表示硬盘忙
    cmp al, 0x08
    jnz .not_ready      ;若未准备好，继续等

;第5步：从0x1f0端口读数据
    mov ax, di
    mov dx, 256
    mul dx          ;被乘数在ax，从传参cx->di->ax，结果高16在dx，低16在ax
                    ;由于结果可知，不会溢出，所以这里丢弃高16
    mov cx, ax      ;di为要读取的扇区数，一个扇区有512字节，每次读入一个字，
                    ;共需di*512/2次，所以di*256
    mov dx, 0x1f0
.go_on_read:
    in ax, dx
    mov [bx], ax
    add bx, 2
    loop .go_on_read
    ret


; 填充扇区剩余空间，并设置魔数
    times 510-($-$$) db 0
    db 0x55,0xaa
