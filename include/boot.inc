;---------- loader and kernel ----------
LOADER_BASE_ADDR equ 0x900 
LOADER_START_SECTOR equ 0x2

;---------- gdt Descriptor attr --------
;DESC_字段名_字段
;
;| 31~24 | 23 | 22  | 21 | 20  | 19~16 | 15 | 14~13 | 12 | 11~8 |  7~0  | 高32位
;| 段基址 | G  | D/B | L  | AVL | 段界限 | P  |  DPL  | S  | TYPE | 段基址 |
;G=Granularity,粒度,说白了就是单位,0为Byte,1为4K
;D/B,指示有效地址和操作数的大小,先不管
;AVL=AVaiLable,对硬件来说没有特殊用途,软件可随意使用
;P,段是否存在,CPU用于检查,为0则抛异常
;DPL=Descriptor Privilege Level,特权级,0max,3min
;S,0为系统段(凡是硬件运行需要用的都称为系统),1为数据段(凡是软件需要用的都称为数据,包括OS)
;TYPE,S确定后该字段才有意义,非系统段时由高到低位分为X-C-R-A
;| 31~16 | 15~0  | 低32位
;| 段基址 | 段界限 |
DESC_G_4K         equ 1_00000000000000000000000b
DESC_D_32         equ 1_0000000000000000000000b
DESC_L            equ 0_000000000000000000000b    ;64位代码标记，此处标记为0便可。
DESC_AVL          equ 0_00000000000000000000b     ;cpu不用此位，暂置为0
DESC_LIMIT_CODE2  equ 1111_0000000000000000b
DESC_LIMIT_DATA2  equ DESC_LIMIT_CODE2
DESC_LIMIT_VIDEO2 equ 0000_000000000000000b
DESC_P	          equ	1_000000000000000b
DESC_DPL_0        equ 00_0000000000000b
DESC_DPL_1        equ 01_0000000000000b
DESC_DPL_2        equ 10_0000000000000b
DESC_DPL_3        equ 11_0000000000000b
DESC_S_CODE       equ 1_000000000000b
DESC_S_DATA       equ DESC_S_CODE
DESC_S_sys        equ 0_000000000000b
DESC_TYPE_CODE    equ 1000_00000000b              ;x=1,c=0,r=0,a=0 代码段是可执行的,非依从的,不可读的,已访问位a清0.  
DESC_TYPE_DATA    equ 0010_00000000b              ;x=0,e=0,w=1,a=0 数据段是不可执行的,向上扩展的,可写的,已访问位a清0.

DESC_CODE_HIGH4   equ (0x00 << 24) + DESC_G_4K + DESC_D_32 + DESC_L + DESC_AVL + DESC_LIMIT_CODE2 + DESC_P + DESC_DPL_0 + DESC_S_CODE + DESC_TYPE_CODE + 0x00
DESC_DATA_HIGH4   equ (0x00 << 24) + DESC_G_4K + DESC_D_32 + DESC_L + DESC_AVL + DESC_LIMIT_DATA2 + DESC_P + DESC_DPL_0 + DESC_S_DATA + DESC_TYPE_DATA + 0x00
DESC_VIDEO_HIGH4  equ (0x00 << 24) + DESC_G_4K + DESC_D_32 + DESC_L + DESC_AVL + DESC_LIMIT_VIDEO2 + DESC_P + DESC_DPL_0 + DESC_S_DATA + DESC_TYPE_DATA + 0x0b

;---------- selector attr --------------
RPL0    equ 00b
RPL1    equ 01b
RPL2    equ 10b
RPL3    equ 11b
TI_GDT  equ 000b
TI_LDT  equ 100b
