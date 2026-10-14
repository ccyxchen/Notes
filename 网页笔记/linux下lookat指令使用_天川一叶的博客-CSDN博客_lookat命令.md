# (176条消息) linux下lookat指令使用_天川一叶的博客-CSDN博客_lookat命令

项目：

展讯Spread9806g Android 7.0平台AR眼镜项目

遇到的问题：

MIPI通路不通，需要读取相关[寄存器](https://so.csdn.net/so/search?q=%E5%AF%84%E5%AD%98%E5%99%A8&spm=1001.2101.3001.7020)数值来判断问题，所以使用lookat指令：

介绍：

1|root@sp9860g_1h10_3g:/ # lookat -h 
 
 Usage: lookat [-l nword] [-s value] [-h] addr_in_hex
 get/set the value of IO reg at addr_in_hex
 -l nword print values of nword continous regs start from 
 addr_in_hex in a formated way
 -s value set a reg at addr_in_hex to value
 -h print this message
 
 
 NOTE:
 \* the addr_in_hex should be 4-byte aligned in hex form
 \* Default is physical address, Using Virtual address If the 
 \* parameters are capital letter: Only the [-L],[-S],(Read/Write) 
 \* will use virtual address

详细介绍：

-l nword addr_in_hex 表示从addr_in_hex开始的寄存器里面以四字节为单位读出来多少个寄存器数据

lookat -l 20 63a00000

-s value addr_in_hex 表示往addr_in_hex寄存器里面写入value
