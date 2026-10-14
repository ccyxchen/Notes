# [嵌入式er笔记]大端小端详解(含代码及详细注释) - 知乎

首发于

[嵌入式er笔记](https://www.zhihu.com/column/c_1250096106878685184)

写文章

登录

[嵌入式er笔记]大端小端详解(含代码及详细注释)[

![embdnote](img/%5B%E5%B5%8C%E5%85%A5%E5%BC%8Fer%E7%AC%94%E8%AE%B0%5D%E5%A4%A7%E7%AB%AF%E5%B0%8F%E7%AB%AF%E8%AF%A6%E8%A7%A3(%E5%90%AB%E4%BB%A3%E7%A0%81%E5%8F%8A%E8%AF%A6%E7%BB%86%E6%B3%A8%E9%87%8A)%20-%20%E7%9F%A5%E4%B9%8E-01.jpg)

](https://www.zhihu.com/people/littlegoal)[embdnote](https://www.zhihu.com/people/littlegoal)56 人赞同了该文章

**之前文章《 [浅谈ARM ABI，Android ABI](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247483758%26idx%3D1%26sn%3D7c182271447da0d2fa517b329c1e4c68%26chksm%3D9bce7956acb9f040a0f8235a7075fcb6f5ad74673ed2caa30d437d4adc837b2d758787e91b6c%26scene%3D21%23wechat_redirect) 》中有提到计划专门一篇文章讲下大小端，今天兑现一下。**

**1>"大端" "小端"的来源**

关于大端小端名词的由来，网传有一个有趣的故事，可以追溯到1726年的Jonathan Swift的《格列佛游记》，其中一篇讲到有两个国家因为吃鸡蛋究竟是先打破较大的一端还是先打破较小的一端而争执不休，甚至爆发了战争。

《格利佛游记》：“Lilliput和Blefuscu这两个强国在过去的36个月中一直在苦战。战争的原因是：我们都知道，吃鸡蛋的时候，原始的方法是打破鸡蛋较大的一端，可是那时的皇帝的祖父由于小时侯吃鸡蛋，按这种方法把手指弄破了，因此他的父亲，就下令，命令所有的子民吃鸡蛋的时候，必须先打破鸡蛋较小的一端，违令者重罚。然后老百姓对此法令极为反感，由此发生了多次叛乱，产生叛乱的原因就是另一个国家Blefuscu的国王大臣煽动起来的。叛乱平息后，流亡的人就逃到这个帝国避难。据估计，先后几次有11000余人情愿si也不肯去打破鸡蛋较小的端吃鸡蛋。”

Swift的《格列佛游记》其实是在讽刺当时英国(Lilliput)和法国(Blefuscu)之间持续的冲突。

现在以大端、小端的命名Big-Endian、Little-Endian看，确实也符合鸡蛋的特征，一切源于生活。

**2> 计算机中“大端”“小端”是指什么**

大端小端真正引入计算机领域，是来自于一位网络协议的早期开创者Danny Cohen，他第一次使用这两个术语指代字节顺序，后来慢慢被大家广泛接受。

字节顺序说的到底是什么，先复习一个基础知识：

**位(bit)**：计算机中的最小数据单位，计算机存储的都是二进制0和1这两个鬼。

**字节(Byte)**：字节是存储空间的基本计量单位，也是内存的基本单位，也是编址单位。例如，一个计算机的内存是4GB，就是该计算机的内存中共有4×1024×1024×1024个字节，意味着它有4G的内存寻址空间。

换算关系：

1 GB = 1024 MB

1 MB = 1024 KB

1 KB = 1024 Bytes

1 Byte = 8 bits

**【Q】：**思考一个问题，通常描述32位二进制数据，为什么是用8个十六进制数呢？如**0x1A2B3C4D**

**【A】：**十六进制(hex)是一种逢16进1的进位制。十六进制的数码有1，2，3，4，5，6，7，8，9，A(10),B(11),C(12),D(13),E(14),F(15)。

**第一种理解：**

4个二进制bit 表示的数值范围是从0000~1111，即0~15, 刚好等同于 一位 16进制数的数值范围0~F(15)。

所以可以类推得出：

1Byte = 8bit；即1个字节包含8个二进制bit，8个二进制bit对应需要2位十六进制数来表示(最大值为 0xFF)；

4Byte = 32bit; 即4个字节包含32个二进制bit，32个二进制bit对应需要8位十六进制数来表示；(最大值为 0xFFFFFFFF)；

**第二种理解：**

因为16=2^4(2的4次方)，所以1位十六进制数可以转化为4位二进制数，即十六进制的每个字符需要用4位二进制位来表示，如0x0为0000，0xF为1111，即1个16进制数为4位二进制bit。

所以反推32位二进制数换算为十六进制数后的位数就变为32÷4=8位，即32位二进制地址信息需要8位十六进制数表示。

**总结下：**

4个二进制位(bit)(不够表示一个字节) = 1个十六进制(hex)。

8个二进制位(bit) = 一个字节(Byte) = 2个十六进制(hex)。

32个二进制位(bit) = 四个字节(Byte) = 8个十六进制(hex)。

所以针对一个32位的数值，如**0x1A2B3C4D**，总共四个字节，两个十六进制数表示一个字节，高位字节为**0x1A**，低位字节为**0x4D**；中间两个字节分别为**0x2B**和**0x3C**；

数值**0x1A2B3C4D**想要在计算机中正确使用，就必须要考虑在内存中将其对应的四个字节合理存储。假设内存的地址都是从低到高分配的，那么对于一个数值多个字节顺序存储就有两种存储方式：

**方式一**、数值的高位字节存放在内存的低地址端，低位字节存放在内存的高地址端：

内存低地址 --------------------> 内存高地址

0x1A | 0x2B | 0x3C | 0x4D

高位字节 <-------------------- 低位字节

**方式二**、数值的低位字节存放在内存的低地址端，高位字节存放在内存的高地址端：

内存低地址 --------------------> 内存高地址

0x4D | 0x3C | 0x2B | 0x1A

低位字节 --------------------> 高位字节

**方式一 ，**我们就称之为 大端模式；即高位字节放在内存的低地址端，低位字节放在内存的高地址端。

**方式二 ，**我们就称之为 小端模式；即低位字节放在内存的低地址端，高位字节放在内存的高地址端。

**画图更直观理解一下：**

![image](https://pic2.zhimg.com/80/v2-1a4d887d6b9a2701a50114e2eac530f5_720w.jpg)

![image](https://pic3.zhimg.com/80/v2-28edbce28d58b8c4f4ff02fc1730929e_720w.jpg)

**总结下：**

- 大端小端是不同的字节顺序存储方式，统称为**字节序**；
- **大端模式**，是指数据的高字节位 保存在 内存的低地址中，而数据的低字节位 保存在 内存的高地址中。这样的存储模式有点儿类似于把数据当作字符串顺序处理：地址由小向大增加，而数据从高位往低位放。和我们”从左到右“阅读习惯一致。
- **小端模式**，是指数据的高字节位 保存在 内存的高地址中，而数据的低字节位 保存在 内存的低地址中。这种存储模式将地址的高低和数据位权有效地结合起来，高地址部分权值高，低地址部分权值低，和我们的逻辑方法一致。

**分享一个私人口语化记忆小技巧：**

- **大端模式**：“【低位】字节却硬要存在【高】地址中“。---“低对高(或高对低)，门不当户不对，真令人头大”，记作大端模式。
- **小端模式**：“【低位】字节正好存在【低】地址中”。--- “低对低，门当户对，你侬我侬”，记作小端模式。

**3> 为什么要学习理解“大端”“小端”**

**大端模式：**

基于其存储特点，符号位在所表示的数据的内存的第一个字节中，便于快速判断数据的正负和大小（CPU做数值运算时从内存中依顺序依次从低位地址到高位地址取数据进行运算，大端就会最先拿到数据的(高字节的)符号位）。

**小端模式：**

基于其存储特点，内存的低地址处存放低字节，所以在强制转换数据时不需要调整字节的内容（比如，把int---4字节强制转换成short---2字节，就可以直接把int数据存储的前两个字节给short就行，因为其前两个字节刚好就是最低的两个字节，符合转换逻辑；另外CPU做数值运算时从内存中依顺序依次从低位地址到高位地址取数据进行运算，开始只管取值，最后刷新最高位地址的符号位就行，这样的运算方式会更高效一些）。

因为两种模式各有优点，存在“你有我无，你无我有”的特点，所以造就了不同的硬件厂商基于不同的效率(角度)考虑，有了不同的硬件设计支持，最终形成了计算机各个相关领域目前并没有采用统一的字节序，没有统一标准的现状。

其实也不难理解，就好比文章开头描述的“吃鸡蛋方式之争一样” 天下之大又有谁能站出来限定或证明，吃鸡蛋必须从“小端”开始，就一定比从“大端”开始 好？或者 吃鸡蛋必须从“大端”开始，就一定比从“小端”开始 好？呢。

**“大端“ ”小端” 各有优点，同吃鸡蛋方式一样，世人都有各自选择的权利。**

**目前我们常见的CPU PowerPC、IBM是大端模式，x86是小端模式。ARM既可以工作在大端模式，也可以工作在小端模式，一般ARM都默认是小端模式。一般通讯协议都采用的是大端模式。**

另外，常见文件的字节序如下：

BMP – Little Endian

GIF – Little Endian

JPEG – Big Endian

RTF – Little Endian

Adobe PS – Big Endian

DXF(AutoCAD) – Variable

所以我们只有理解“大端”“小端”，才能在跨平台、跨芯片、跨系统，跨网络通信时，实时对内存字节序进行检查和转换，保证传递内容的正确性。假设没有操作系统工程师，网络工程师在背后默默对字节序的检查和转换，可能你用你的X86机器通过QQ给我PowerPC机器QQ表了个白，但数据在内存中传递乱的yipi，消息到了以后，前言不搭后语，我都完全不知道你想说什么，也不知道你在表白，彼此完美错过将是结局。

**4> 通过C代码检测当前计算机环境采用的是大端模式还是小端模式。**

**举例：**

- **方式一**： 借助联合体union的特性实现(联合体类型数据所占的内存空间等于其最大的成员所占的空间，对联合体内部所有成员的存取都是相对于该联合体基地址的偏移量为 0 处开始，也就都是从该联合体所占内存的首地址位置开始。）

```c
#include <stdio.h>
int main()
{
    union{
      int a;  //4 bytes
      char b; //1 byte
    } data;

    data.a = 1; //占4 bytes，十六进制可表示为 0x 00 00 00 01

    //b因为是char型只占1Byte，a因为是int型占4Byte
    //所以，在联合体data所占内存中，b所占内存等于a所占内存的低地址部分
    if(1 == data.b){ //走该case说明a的低字节，被取给到了b，即a的低字节存在了联合体所占内存的(起始)低地址，符合小端模式特征
      printf("Little_Endian\n");
     } else {
      printf("Big_Endian\n");
     }
   return 0;
}
```

**说明：**

赋值 1 是数据的低字节位(0x00000001)。

如果 1 被存储在 data所占内存 的低地址中，那data.b 的值将会是 1，就是小端模式。

如果 1 被存储在 data所占内存 的高地址中，那data.b 的值将会是 0，就是大端模式。

- **方式二**： ： 通过将int强制类型转换成char单字节，判断起始存储位置内容实现。

```c
#include <stdio.h>
int main()
{
    int a = 1; //占4 bytes，十六进制可表示为 0x 00 00 00 01

     //b相当于取了a的低地址部分
    char *b =(char *)&a; //占1 byte

    if (1 == *b) {//走该case说明a的低字节，被取给到了b，即a的低字节对应a所占内存的低地址，符合小端模式特征
        printf("Little_Endian!\n");
    } else {
        printf("Big_Endian!\n");
    }
    return 0;
}
```

**说明：**

赋值 1 是数据的低字节位(0x00000001)。

如果 1 被存储在 a所占内存 的低地址中，那b的值将会是 1，就是小端模式。

如果 1 被存储在 a所占内存 的高地址中，那b的值将会是 0，就是大端模式。

——————————

**5>End.PS:**网上有很多，用MSB和LSB讲大端和小端的描述，我们一定需要注意，**大端和小端描述的是字节之间的关系，而MSB、LSB描述的是Bit位之间的关系**。字节是存储空间的基本计量单位，所以通过高位字节和低位字节来理解大小端存储是最为直接的。

**MSB**: Most Significant Bit ------- 最高有效位(指二进制中最高值的比特)

**LSB:** Least Significant Bit ------- 最低有效位(指二进制中最高值的比特)

**当然，也可以通过MSB/LSB实现大端小端的判断和检测，举例代码如下：**

```c
#include <stdio.h>

int main(void)
{
    union {
      struct {
        char a:1; //定义位域为 1 bit[不知位域何物，还请先自行查阅一下，后续文章也会专门讲到]
      } s;
      char b;
    } data;

    data.b = 8;//8(Decimal) == 1000(Binary)，MSB is 1，LSB is 0

    //在联合体data所占内存中，data.s.a所占内存bit等于data.b所占内存低地址部分的bit
    if (1 == data.s.a) {//走该case说明data.b的MSB是被存储在union所占内存的低地址中，符合大端序的特征
        printf("Big_Endian\n");
    } else {
        printf("Little_Endian\n");
    }
    return 0;
}
```

**最近文章：**

>文章 | [源码中看到一个.hpp文件，差点闹了笑话](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247484868%26idx%3D1%26sn%3D7870cb2b2c3b6ae39e550dcba0be89d1%26chksm%3D9bce7dfcacb9f4ea3486165ef80f33d8e2c7da07e2d8803418d8e1ee76300fc46bceb36bf8ab%26scene%3D21%23wechat_redirect)

>文章 | [Hi~main~](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247484772%26idx%3D1%26sn%3Dabd3253c74759fb4aeee7a944018a72c%26chksm%3D9bce7d5cacb9f44add3bb98dcfec2c8deb64944cf7ac8c2e3245fa1ba3c9ba0cc4491d4176da%26scene%3D21%23wechat_redirect)

>文章 | [媳妇电脑卡顿了，我有事干了！](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247484857%26idx%3D1%26sn%3Dfb2e42f5996f3723bc96971891449e1e%26chksm%3D9bce7d81acb9f497970ff3c796d60ca8d52379365667218b61540ebdefa9b9ff4c4200b4b8df%26scene%3D21%23wechat_redirect)

>文章 | [我应该更早一点认识Git](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247484631%26idx%3D1%26sn%3D0ed9e3472f74dec4ca8b2435a1527b2a%26chksm%3D9bce7cefacb9f5f9f7636708a352598e7e8988c90b90193da902fb0ddb1049b86a47ec52ca4c%26scene%3D21%23wechat_redirect)

>文章 | [linux开发vi/vim使用知多少](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247484723%26idx%3D1%26sn%3D66be566054e242535066e523e4b25639%26chksm%3D9bce7d0bacb9f41d06b5990a932370191f4f7c23174bef9dd0e4c6e2132073cb818f0c22c099%26scene%3D21%23wechat_redirect)

>文章 | [常用linux命令cat、tac、head、tail笔记](https://zhuanlan.zhihu.com/p/144718837/http%3Cb%3E://%3C/b%3Emp.weixin.qq.com/s?__biz=MzAxODkwMzM4Mw==&mid=2247484838&idx=1&sn=56c15b7136687d2a84419ed74d0fc3f7&chksm=9bce7d9eacb9f48891daa2ee084affcc55e33cc2a4240f17480f28d19a7b0edb3c4cc5227f6f&scene=21#wechat_redirect)

>文章 | [linux下查找文件，看这篇就够了](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247484767%26idx%3D1%26sn%3D6cad500d6e456191adad65f13faa519d%26chksm%3D9bce7d67acb9f471d8cb397d128ce73316fad7b50a5ffd14c15fb5997810d97ebdaa788d12d7%26scene%3D21%23wechat_redirect)

>文章 | [高考后志愿一路脱档的“惊悚”回忆](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247484824%26idx%3D1%26sn%3Df60b646c58030fc35102504af77b66e3%26chksm%3D9bce7da0acb9f4b66dd0f59ed5fe30b3f6888ae98df08bfc4fff72ec712f6b8382921851f6e1%26scene%3D21%23wechat_redirect)

>文章 | [新入职，尽快平移老员工的环境配置是正道](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247484830%26idx%3D1%26sn%3Df50ff6c8f86e930e9378345850d428f1%26chksm%3D9bce7da6acb9f4b0887cb18ea6d51306decaaf31ccdbde5d7f3a8936947d109fd8862a125023%26scene%3D21%23wechat_redirect)

>文章 | [写shell脚本偷了个懒，syntax error之谜](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247484803%26idx%3D1%26sn%3Dd00dc5167d77ccee8792f50b80159c58%26chksm%3D9bce7dbbacb9f4ad1fb63e09eb734c905a83ba1f4aa825889a233f4e23beb43719efa9ddac6d%26scene%3D21%23wechat_redirect)

>文章 | [程序员不应该就是专职敲代码的吗](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247484751%26idx%3D1%26sn%3D5fb5cff7bfad7c6b374a6625c95769c4%26chksm%3D9bce7d77acb9f461453d75e841b3edd6b99704173cddc7d6bddcde85dbe0707c3021a2b28004%26scene%3D21%23wechat_redirect)

[>文章 |](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247484010%26idx%3D1%26sn%3D2e537b82782ffa3ad467ddafbc2270e3%26chksm%3D9bce7a52acb9f344dec34b546a433978b32f5206f6be1a95931bf276826d45b6b4fbb26d5b49%26scene%3D21%23wechat_redirect)[大端小端详解(含代码及详细注释)](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247483886%26idx%3D1%26sn%3Db1acf2a4c456d00bb49d17aa6efa6754%26chksm%3D9bce79d6acb9f0c095ef3b36903aa0774a0edd768f68d9990486aaa39ac25b5e06389dbe6885%26scene%3D21%23wechat_redirect)

[>文章 |](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247484010%26idx%3D1%26sn%3D2e537b82782ffa3ad467ddafbc2270e3%26chksm%3D9bce7a52acb9f344dec34b546a433978b32f5206f6be1a95931bf276826d45b6b4fbb26d5b49%26scene%3D21%23wechat_redirect)[浅谈ARM ABI，Android ABI](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247483758%26idx%3D1%26sn%3D7c182271447da0d2fa517b329c1e4c68%26chksm%3D9bce7956acb9f040a0f8235a7075fcb6f5ad74673ed2caa30d437d4adc837b2d758787e91b6c%26scene%3D21%23wechat_redirect)

[>文章 |](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247484010%26idx%3D1%26sn%3D2e537b82782ffa3ad467ddafbc2270e3%26chksm%3D9bce7a52acb9f344dec34b546a433978b32f5206f6be1a95931bf276826d45b6b4fbb26d5b49%26scene%3D21%23wechat_redirect)[CPU、ARM、架构(及指令集)关系](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247483736%26idx%3D1%26sn%3Da87ff4a290c521b6d84bc7bfd2a0c687%26chksm%3D9bce7960acb9f076cd9e9b49cf48f0505a9628b149d63bc87510ace40ad83bd0783f0f7efdde%26scene%3D21%23wechat_redirect)

>文章 | [我毕业了(来自小学妹的毕业随笔)](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247484695%26idx%3D1%26sn%3Dd97206da287fa2464ca701840b626067%26chksm%3D9bce7d2facb9f439b903a9b128005d6e61fb125dcbb1ee5ff9abb24aca1e2fe44b73e50e8ad8%26scene%3D21%23wechat_redirect)

>文章 | [手机屏幕封装技术及其分类相关知识](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247484678%26idx%3D1%26sn%3D867e28809c860e4d4da584dbc3677212%26chksm%3D9bce7d3eacb9f4280fbc0cdd2790cb4a8452e502841f42d3028ca9548eec0162f32c01b20fff%26scene%3D21%23wechat_redirect)

>文章 | [最近面试了一些人，记录下面后感](https://link.zhihu.com/?target=http%3A//mp.weixin.qq.com/s%3F__biz%3DMzAxODkwMzM4Mw%3D%3D%26mid%3D2247484784%26idx%3D1%26sn%3D0d8605dce5b36e8dfeeb1eb227cd3fcf%26chksm%3D9bce7d48acb9f45e4231cbe9b46aa7483c0e7a9424329498b799a76a8cb26bdd804b8282b8e8%26scene%3D21%23wechat_redirect)

>专辑 | [C/C++细碎](https://link.zhihu.com/?target=https%3A//mp.weixin.qq.com/mp/appmsgalbum%3Faction%3Dgetalbum%26album_id%3D1373204218118815747%26__biz%3DMzAxODkwMzM4Mw%3D%3D%23wechat_redirect)

>专辑 | [磨刀不误砍柴工](https://link.zhihu.com/?target=https%3A//mp.weixin.qq.com/mp/appmsgalbum%3Faction%3Dgetalbum%26album_id%3D1423867493378310144%26__biz%3DMzAxODkwMzM4Mw%3D%3D%23wechat_redirect)

**From：【嵌入式er笔记】嵌入式、Linux、C/C++、ARM、Android、IoT等技术相关知识，以及职场、生活经验和感悟笔记。**

编辑于 08-28 11:05

[大端](https://www.zhihu.com/topic/20285092)

[小端序（little-endian）](https://www.zhihu.com/topic/20168830)

[大端序/网络字节序（big-endian）](https://www.zhihu.com/topic/20168828)

​赞同 56​

​10 条评论

​分享

​喜欢

​收藏

​申请转载

​

### 文章被以下专栏收录

[

![嵌入式er笔记](img/%5B%E5%B5%8C%E5%85%A5%E5%BC%8Fer%E7%AC%94%E8%AE%B0%5D%E5%A4%A7%E7%AB%AF%E5%B0%8F%E7%AB%AF%E8%AF%A6%E8%A7%A3(%E5%90%AB%E4%BB%A3%E7%A0%81%E5%8F%8A%E8%AF%A6%E7%BB%86%E6%B3%A8%E9%87%8A)%20-%20%E7%9F%A5%E4%B9%8E-02.jpg)

](https://www.zhihu.com/column/c_1250096106878685184)

## 嵌入式er笔记

嵌入式/Linux/Android开发/工具笔记

### 推荐阅读

[大端序和小端序字节存储顺序主要分为大端序（Big-endian）和小端序（Little-endian），区别如下Big-endian：高位字节存入低地址，低位字节存入高地址Little-endian：低位字节存入低地址，高位字节存入高地…Casua...发表于极客方舟](https://zhuanlan.zhihu.com/p/77436031)

[

![大端小端](img/%5B%E5%B5%8C%E5%85%A5%E5%BC%8Fer%E7%AC%94%E8%AE%B0%5D%E5%A4%A7%E7%AB%AF%E5%B0%8F%E7%AB%AF%E8%AF%A6%E8%A7%A3(%E5%90%AB%E4%BB%A3%E7%A0%81%E5%8F%8A%E8%AF%A6%E7%BB%86%E6%B3%A8%E9%87%8A)%20-%20%E7%9F%A5%E4%B9%8E-03.jpg)

大端小端江峰](https://zhuanlan.zhihu.com/p/36149865)

[什么是大端序和小端序，为什么要有字节序？什么是字节序 字节序，又称端序或尾序（英语中用单词：Endianness 表示），在计算机领域中，指电脑内存中或在数字通信链路中，占用多个字节的数据的字节排列顺序。在几乎所有的平台上，多字…Kevin...发表于网管叨bi...](https://zhuanlan.zhihu.com/p/352145413)

[大端模式和小端模式一、什么是大端，什么是小端0x123456在内存中的存储方式 - 大端模式 低地址 -----> 高地址 0x12 | 0x34 | 0x56 - 小端模式 低地址 -----> 高地址 0x56 | 0x34 | 0x12 不难看出大端模…胡振宏发表于改不完的b...](https://zhuanlan.zhihu.com/p/97821726)

## 10 条评论

​切换为时间排序

写下你的评论...

发布

- [ ![红领巾](img/%5B%E5%B5%8C%E5%85%A5%E5%BC%8Fer%E7%AC%94%E8%AE%B0%5D%E5%A4%A7%E7%AB%AF%E5%B0%8F%E7%AB%AF%E8%AF%A6%E8%A7%A3(%E5%90%AB%E4%BB%A3%E7%A0%81%E5%8F%8A%E8%AF%A6%E7%BB%86%E6%B3%A8%E9%87%8A)%20-%20%E7%9F%A5%E4%B9%8E-04.jpg) ](https://www.zhihu.com/people/hong-ling-jin-3-47)[红领巾](https://www.zhihu.com/people/hong-ling-jin-3-47)07-06当然，也可以通过MSB/LSB实现大端小端的判断和检测 你好，这句是否意味着，对于一个主机而言，字节序的大小端是否一定等同于bit序的大小端呢？ 主要是这句里面出现了 也可以 三个字。有点疑惑，希望能解惑，谢谢。​赞​回复​踩​ 举报
- [ ![embdnote](img/%5B%E5%B5%8C%E5%85%A5%E5%BC%8Fer%E7%AC%94%E8%AE%B0%5D%E5%A4%A7%E7%AB%AF%E5%B0%8F%E7%AB%AF%E8%AF%A6%E8%A7%A3(%E5%90%AB%E4%BB%A3%E7%A0%81%E5%8F%8A%E8%AF%A6%E7%BB%86%E6%B3%A8%E9%87%8A)%20-%20%E7%9F%A5%E4%B9%8E-05.jpg) ](https://www.zhihu.com/people/littlegoal)[embdnote](https://www.zhihu.com/people/littlegoal) (作者) 回复[红领巾](https://www.zhihu.com/people/hong-ling-jin-3-47)07-061.“也可以”，是“还可以有另外一种方式”的意思。也就是想通过MSB LSB判断大小端，是没有任何问题的。只要个人认为，便于自己理解的方式就是是最好的方式。属于个人理解的偏好吧。 2.从你的描述看，你可能对概念理解有点偏差， MSB: Most Significant Bit ------- 最高有效位(指二进制中最高值的比特) LSB: Least Significant Bit ------- 最低有效位(指二进制中最高值的比特) 这两个概念，只是对一个数值，十六进制，八进制，十进制，等等数值，最后都转为二进制来而言的高位bit和低位bit而已，数值本身而言，是没有大小端之说的。大小端说的是存储(顺序)的方式。可以通过代码逻辑检测判断数值的MSB ， LSB，看他们分别的存储位置(顺序)，进而来看是大端存储方式，还是小端方式。道理和利用，通过字节来判断是一样的。 希望可以帮到你进一步理解。​赞​回复​踩​ 举报

- [ ![Typedef-FMTURE](img/%5B%E5%B5%8C%E5%85%A5%E5%BC%8Fer%E7%AC%94%E8%AE%B0%5D%E5%A4%A7%E7%AB%AF%E5%B0%8F%E7%AB%AF%E8%AF%A6%E8%A7%A3(%E5%90%AB%E4%BB%A3%E7%A0%81%E5%8F%8A%E8%AF%A6%E7%BB%86%E6%B3%A8%E9%87%8A)%20-%20%E7%9F%A5%E4%B9%8E-06.jpg) ](https://www.zhihu.com/people/hello-zju)[Typedef-FMTURE](https://www.zhihu.com/people/hello-zju)05-26比如发一个字节的数据，那MSB是放在地址的高位还是低位呢?​赞​回复​踩​ 举报
- [ ![embdnote](img/%5B%E5%B5%8C%E5%85%A5%E5%BC%8Fer%E7%AC%94%E8%AE%B0%5D%E5%A4%A7%E7%AB%AF%E5%B0%8F%E7%AB%AF%E8%AF%A6%E8%A7%A3(%E5%90%AB%E4%BB%A3%E7%A0%81%E5%8F%8A%E8%AF%A6%E7%BB%86%E6%B3%A8%E9%87%8A)%20-%20%E7%9F%A5%E4%B9%8E-07.jpg) ](https://www.zhihu.com/people/littlegoal)[embdnote](https://www.zhihu.com/people/littlegoal) (作者) 回复[Typedef-FMTURE](https://www.zhihu.com/people/hello-zju)06-23你好，具体发送时候的字节顺序和具体的协议流有关。比如，I2C协议就是先发送最高位，也就是MSB，借助数据移位寄存器实现。​赞​回复​踩​ 举报

- [ ![巧妙计划](img/%5B%E5%B5%8C%E5%85%A5%E5%BC%8Fer%E7%AC%94%E8%AE%B0%5D%E5%A4%A7%E7%AB%AF%E5%B0%8F%E7%AB%AF%E8%AF%A6%E8%A7%A3(%E5%90%AB%E4%BB%A3%E7%A0%81%E5%8F%8A%E8%AF%A6%E7%BB%86%E6%B3%A8%E9%87%8A)%20-%20%E7%9F%A5%E4%B9%8E-08.jpg) ](https://www.zhihu.com/people/qiao-miao-ji-hua)[巧妙计划](https://www.zhihu.com/people/qiao-miao-ji-hua)03-07一下子明白了，感谢作者！本来纠结于大端小端模式与汇编语言中通用寄存不同位数引用的对应关系，反思来看是我搞乱了，恰恰是小端模式方便不同位通用寄存器的快速引用，如AL AH AX EAX ![[思考]](https://pic4.zhimg.com/v2-bffb2bf11422c5ef7d8949788114c2ab.png) ​赞​回复​踩​ 举报

- [ ![倾卿哥哥](img/%5B%E5%B5%8C%E5%85%A5%E5%BC%8Fer%E7%AC%94%E8%AE%B0%5D%E5%A4%A7%E7%AB%AF%E5%B0%8F%E7%AB%AF%E8%AF%A6%E8%A7%A3(%E5%90%AB%E4%BB%A3%E7%A0%81%E5%8F%8A%E8%AF%A6%E7%BB%86%E6%B3%A8%E9%87%8A)%20-%20%E7%9F%A5%E4%B9%8E-09.jpg) ](https://www.zhihu.com/people/tian-ye-cha-42)[倾卿哥哥](https://www.zhihu.com/people/tian-ye-cha-42)2020-10-02这个地址低位是左边还是右边？还是跟数据表示一样默认左高右低呢？​赞​回复​踩​ 举报
- [ ![embdnote](img/%5B%E5%B5%8C%E5%85%A5%E5%BC%8Fer%E7%AC%94%E8%AE%B0%5D%E5%A4%A7%E7%AB%AF%E5%B0%8F%E7%AB%AF%E8%AF%A6%E8%A7%A3(%E5%90%AB%E4%BB%A3%E7%A0%81%E5%8F%8A%E8%AF%A6%E7%BB%86%E6%B3%A8%E9%87%8A)%20-%20%E7%9F%A5%E4%B9%8E-10.jpg) ](https://www.zhihu.com/people/littlegoal)[embdnote](https://www.zhihu.com/people/littlegoal) (作者) 回复[倾卿哥哥](https://www.zhihu.com/people/tian-ye-cha-42)2020-10-08地址表示是 0x高低 表示的，比如 0x34 0x1234 希望便于你理解 ![[握手]](https://pic2.zhimg.com/v2-f5aa165e86b5c9ed3b7bee821da59365.png) ​赞​回复​踩​ 举报
- [ ![倾卿哥哥](img/%5B%E5%B5%8C%E5%85%A5%E5%BC%8Fer%E7%AC%94%E8%AE%B0%5D%E5%A4%A7%E7%AB%AF%E5%B0%8F%E7%AB%AF%E8%AF%A6%E8%A7%A3(%E5%90%AB%E4%BB%A3%E7%A0%81%E5%8F%8A%E8%AF%A6%E7%BB%86%E6%B3%A8%E9%87%8A)%20-%20%E7%9F%A5%E4%B9%8E-11.jpg) ](https://www.zhihu.com/people/tian-ye-cha-42)[倾卿哥哥](https://www.zhihu.com/people/tian-ye-cha-42)回复[embdnote](https://www.zhihu.com/people/littlegoal) (作者) 2020-10-080x后面左高右低嘛​赞​回复​踩​ 举报

- [ ![龙宝宝](img/%5B%E5%B5%8C%E5%85%A5%E5%BC%8Fer%E7%AC%94%E8%AE%B0%5D%E5%A4%A7%E7%AB%AF%E5%B0%8F%E7%AB%AF%E8%AF%A6%E8%A7%A3(%E5%90%AB%E4%BB%A3%E7%A0%81%E5%8F%8A%E8%AF%A6%E7%BB%86%E6%B3%A8%E9%87%8A)%20-%20%E7%9F%A5%E4%B9%8E-12.jpg) ](https://www.zhihu.com/people/yu-luo-ting-40)[龙宝宝](https://www.zhihu.com/people/yu-luo-ting-40)2020-10-02棒棒哒​赞​回复​踩​ 举报
