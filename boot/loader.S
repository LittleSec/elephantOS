%include "boot.inc"
section loader vstart=LOADER_BASE_ADDR

;打印字符串"2 LOADER"，输出背景色闪烁红色色，前景色高亮蓝色
;bit 15 14 13 12 11 10 9 8 7 6 5 4 3 2 1 1
;   |K  R  G  B | I  R G B |    ASCII     |
;   |   背景色   |   前景色  |
; 是否闪烁       高亮位
;   |1  1  0  0 | 1  0 0 1 | <==> (0xC9)
mov byte [gs:0x00], '2'
mov byte [gs:0x01], 0xC9

mov byte [gs:0x02], ' '
mov byte [gs:0x03], 0xC9

mov byte [gs:0x04], 'L'
mov byte [gs:0x05], 0xC9   

mov byte [gs:0x06], 'O'
mov byte [gs:0x07], 0xC9

mov byte [gs:0x08], 'A'
mov byte [gs:0x09], 0xC9

mov byte [gs:0x0a], 'D'
mov byte [gs:0x0b], 0xC9

mov byte [gs:0x0c], 'E'
mov byte [gs:0x0d], 0xC9

mov byte [gs:0x0e], 'R'
mov byte [gs:0x0f], 0xC9

jmp $     ;dead loop
