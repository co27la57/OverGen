# host/Makefile —— 交叉编译 ARM 用户态程序
#
# 用法：
#   本地编译（x86 上语法检查）：  make
#   交叉编译（Zynq ARM）：        make CROSS=arm-linux-gnueabihf-
#   静态链接（推荐，避免 rootfs 缺库）： 见 CFLAGS 中 -static
# ---------------------------------------------------------------------------
CROSS   ?=
CC      := $(CROSS)gcc
CFLAGS  := -O2 -Wall -Wextra -static
TARGET  := gemm_demo
SRCS    := gemm_demo.c overlay_driver.c
HDRS    := overlay_driver.h

all: $(TARGET)

$(TARGET): $(SRCS) $(HDRS)
	$(CC) $(CFLAGS) -o $@ $(SRCS)

clean:
	rm -f $(TARGET)

.PHONY: all clean
