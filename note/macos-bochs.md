>这里只列出与书中的不同之处
>
>部分内容参考:
>
>https://zhuanlan.zhihu.com/p/57015430
>
>https://blog.nswebfrog.com/2017/02/03/config-bochs


### 关于版本

使用 bochs-2.6.9 而不是书中的 bochs-2.6.2 版本，因为在 macOS Catalina 10.15.6 对 x11/sdl 等图形窗口支持不友好，使用 sdl2 会友好很多，而 bochs-2.6.2 不支持 sdl2，故采用 boch-2.6.9，相应的 bochsrc 配置也要修改。注意，需要修改 bochs 源码才能构建，下面会说明。

----------

### 下载、构建
```shell
# dependency
brew install sdl2

# download
wget https://nchc.dl.sourceforge.net/project/bochs/bochs/2.6.9/bochs-2.6.9.tar.gz
tar xvf bochs-2.6.9.tar.gz
cd bochs-2.6.9

# fix source code, add (char *)
# vim iodev/hdimage/cdrom_osx.cc
# line 194
# if ((devname = strrchr(devpath, '/')) != NULL)
# change into
# if ((devname = (char *)strrchr(devpath, '/')) != NULL)

# build
./configure \
--prefix=/path/to/prefix \
--enable-debugger \
--enable-disasm \
--enable-iodebug \
--enable-x86-debugger \
--with-sdl2 \
--disable-debugger-gui
# ./configure --prefix=/path/to/prefix --enable-debugger --enable-disasm --enable-iodebug --enable-x86-debugger --with-sdl2 --disable-debugger-gui
make -j4
make install
```

----------

### bochsrc 配置项
1. 键盘配置使用 `keyboard: map=/path/to/mapfile`, 而不是 `keyboard_mapping: enabled=1, map=/path/to/mapfile`
2. 键盘映射使用的文件是 `/path/to/bochs-2.6.9/share/bochs/keymaps/sdl2-pc-us.map`
