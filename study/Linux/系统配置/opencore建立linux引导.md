# 使用opencore建立ubuntu 引导

先决条件：
    在opencore中有添加openshell工具。

## 获取Ubuntu efi分区信息

重新开机进入opencore, 选择openshell.进入openshell后会打印分区映射表。

![1](../../tmpimage/20230216225103.png)  
根据我安装Ubuntu时创建的efi分区，我的efi分区是在FS0:上

输入下面几行命令将分区映射表保存到文件中。

输入FS0:

再输入ls进入子目录 就可以看到EFI了

![2](../../tmpimage/20230216225253.png)  
进入EFI目录， cd EFI

可以确认这就是我们的引导分区

然后输入map > map.txt生成文件到efi目录下

重启进入mac系统！

挂载efi分区 可以看到目录里已经多了个文本

![3](../../tmpimage/20230216225741.png)  

打开文本可以看到生成多个内容，这里我们选择FS0,要把字符串全部复制了。

使用编辑器打开opencore的config.list文件，在Misc->Entries 下新建项，内容如下：

```xml
<key>Entries</key>
<array>
    <dict>
        <key>Arguments</key>
        <string></string>
        <key>Auxiliary</key>
        <false/>
        <key>Comment</key>
        <string>Not signed for security reasons</string>
        <key>Enabled</key>
        <true/>
        <key>Flavour</key>
        <string>Auto</string>
        <key>Name</key>
        <string>Fedora</string>
        <key>Path</key>
        <string>PciRoot(0x0)/Pci(0x17,0x0)/Sata(0x4,0xFFFF,0x0)/HD(1,GPT,BF9DFA6C-DC5C-4F81-BBBB-195449B6F550,0x28,0x64000)/\EFI\ubuntu\grubx64.efi</string>
        <key>TextMode</key>
        <false/>
    </dict>
</array>
```

重启进入opencore,可以看到多了一个名为Ubuntu的引导项，选择该项即可启动Ubuntu。
