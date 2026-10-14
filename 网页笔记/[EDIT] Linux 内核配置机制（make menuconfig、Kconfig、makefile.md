# [EDIT] Linux 内核配置机制（make menuconfig、Kconfig、makefile

**前面我们介绍模块编程的时候介绍了驱动进入内核有两种方式：模块和直接编译进内核，并介绍了模块的一种 编译方式——在一个独立的文件夹通过makefile配合内核源码路径完成**

|  |
| --- |

**<span style="color:#33f">那么如何将驱动直接编译进内核呢？</span>**

**<span style="color:#33f"> 在我们实际内核的移植配置过程中经常听说的内核裁剪又是怎么么回事呢？</span>**

**<span style="color:#33f">
我们在进行linux内核配置的时候经常会执行make menuconfig这个命令，然后屏幕上会出现以下界面：</span>**

![image](file:///home/chenyx/workspace/Notes/study/Linux/%E7%BC%96%E8%AF%91%E7%B3%BB%E7%BB%9F/:/cd7056b6dd384a8b95599741ce568f03)

**<span style="color:#33f">这个界面是怎么生成的呢？</span>**

**<span style="color:#33f">跟我们经常说的内核配置与与编译又有什么关系呢？</span>**

**<span style="color:#33f">下面我们借此来讲解一下linux内核的配置机制及其编译过程。
</span>**

<span style="color:red">**一、配置系统的基本结构**
</span>

**<span style="color:red">Linux内核的配置系统由三个部分组成，分别是：</span>**

**<span style="color:#33f">
 1、Makefile：分布在 Linux 内核源代码根目录及各层目录中，定义 Linux 内核的编译规则；</span>**

**<span style="color:#33f"> 2、配置文件（config.in(2.4内核，2.6内核)）：给用户提供配置选择的功能；</span>**

**<span style="color:#33f"> 3、配置工具：包括配置命令解释器（对配置脚本中使用的配置命令进行解释）和配置用户界面（提供基于字符界面、基于 Ncurses 图形界面以及基于 Xwindows 图形界面的用户配置界面，各自对应于 Make config、Make menuconfig 和 make xconfig）。</span>**

这些配置工具都是使用脚本语言，如 Tcl/TK、Perl 编写的（也包含一些用 C 编写的代码）。本文并不是对配置系统本身进行分析，而是介绍如何使用配置系统。所以，除非是配置系统的维护者，一般的内核开发者无须了解它们的原理，只需要知道如何编写 Makefile 和配置文件就可以。

**<span style="color:red">二、makefile menuconfig过程讲解</span>**

<span style="color:red">**当我们在执行make menuconfig这个命令时，系统到底帮我们做了哪些工作呢？**</span>

<span style="color:red">**这里面一共涉及到了一下几个文件我们来一一讲解**</span>

**<span style="color:#33f">Linux内核根目录下的scripts文件夹</span><span style="color:#33f">arch/$ARCH/Kconfig文件、各层目录下的Kconfig文件</span><span style="color:#33f"> Linux内核根目录下的makefile文件、各层目录下的makefile文件 </span><span style="color:#33f"> Linux内核根目录下的的.config文件、arm/$ARCH/下的config文件 </span><span style="color:#33f">Linux内核根目录下的 include/generated/autoconf.h文件</span>**

**<span style="color:#33f">
1）scripts文件夹存放的是跟make menuconfig配置界面的图形绘制相关的文件，我们作为使用者无需关心这个文件夹的内容</span>**

**<span style="color:#33f">
2）当我们执行make menuconfig命令出现上述蓝色配置界面以前，系统帮我们做了以下工作：</span>**

**<span style="color:#33f"> 首先系统会读取arch/$ARCH/目录下的Kconfig文件生成整个配置界面选项（Kconfig是整个linux配置机制的核心），那么ARCH环境变量的值等于多少呢？</span>**

**<span style="color:#33f">它是由linux内核根目录下的makefile文件决定的，在makefile下有此环境变量的定义：</span>**

![image](file:///home/chenyx/workspace/Notes/study/Linux/%E7%BC%96%E8%AF%91%E7%B3%BB%E7%BB%9F/:/c00689cc7a134950875bd1923bcda7ea)

**<span style="color:#33f">或者通过 make ARCH=arm menuconfig命令来生成配置界面，
默认生成的界面是所有参数都是没有值的</span>**

**<span style="color:#33f">比如教务处进行考试，考试科数可能有外语、语文、数学等科，这里相当于我们选择了arm科可进行考试，</span><span style="color:#33f">系统就会读取arm/arm/kconfig文件生成配置选项（选择了arm科的卷子），系统还提供了x86科、milps科等10几门功课的考试题</span>**

**<span style="color:#33f">3）假设教务处比较“仁慈”，为了怕某些同学做不错试题，还给我们准备了一份参考答案（默认配置选项），存放在arch/$ARCH/configs下，对于arm科来说就是arch/arm/configs文件夹：</span>**

![image](file:///home/chenyx/workspace/Notes/study/Linux/%E7%BC%96%E8%AF%91%E7%B3%BB%E7%BB%9F/:/e35cf89928c04688b2aa0de75699b1a9)

**<span style="color:#33f">
此文件夹中有许多选项，系统会读取哪个呢？内核默认会读取linux内核根目录下.config文件作为内核的默认选项（试题的参考答案），我们一般会根据开发板的类型从中选取一个与我们开发板最接近的系列到Linux内核根目录下（选择一个最接近的参考答案）</span>**

**<span style="color:red">#cp arch/arm/configs/s3c2410_defconfig .config</span>**

**<span style="color:red">4).config</span>**

**<span style="color:#33f">
假设教务处留了一个心眼，他提供的参考答案并不完全正确（.config文件与我们的板子并不是完全匹配），这时我们可以选择直接修改.config文件然后执行make menuconfig命令读取新的选项</span>**

**<span style="color:#33f">
 但是一般我们不采取这个方案，我们选择在配置界面中通过空格、esc、回车选择某些选项选中或者不选中，最后保存退出的时候，Linux内核会把新的选项（正确的参考答案）更新到.config中，此时我们可以把.config重命名为其它文件保存起来（当你执行make distclean时系统会把.config文件删除），以后我们再配置内核时就不需要再去arch/arm/configs下考取相应的文件了，省去了重新配置的麻烦，直接将保存的.config文件复制为.config即可.</span>**

**<span style="color:red">5）经过以上两步，我们可以正确的读取、配置我们需要的界面了</span>**

**<span style="color:#33f">那么他们如何跟makefile文件建立编译关系呢？</span>**

**<span style="color:#33f">当你保存make menuconfig选项时，系统会除了会自动更新.config外，还会将所有的选项以宏的形式保存在</span>**

**<span style="color:#33f">
Linux内核根目录下的 include/generated/autoconf.h文件下</span>**

![image](file:///home/chenyx/workspace/Notes/study/Linux/%E7%BC%96%E8%AF%91%E7%B3%BB%E7%BB%9F/:/4e78c1d49aa14f64a76a22929404ee00)

**<span style="color:#33f">内核中的源代码就都会包含以上.h文件，跟宏的定义情况进行条件编译。
</span>**

**<span style="color:#33f">当我们需要对一个文件整体选择如是否编译时，还需要修改对应的makefile文件，例如：</span>**

![image](file:///home/chenyx/workspace/Notes/study/Linux/%E7%BC%96%E8%AF%91%E7%B3%BB%E7%BB%9F/:/1389e92770d44e4fbdbbbb3c44ef6bca)

**<span style="color:#33f"> 我们选择是否要编译s3c2410_ts.c这个文件时，makefile会根据CONFIG_TOUCHSCREEN_S3C2410来决定是编译此文件，此宏是在Kconfig文件中定义，当我们配置完成后，会出现在.config及autconf中，至此，我们就完成了整个linux内核的编译过程。</span>**

**<span style="color:#33f">
 最后我们会发现，整个linux内核配置过程中，留给用户的接口其实只有各层Kconfig、makefile文件以及对应的源文件。</span>**

**<span style="color:#33f"> 比如我们如果想要给内核增加一个功能，并且通过make menuconfig控制其声称过程</span>**

**<span style="color:#33f"> 首先需要做的工作是：修改对应目录下的Kconfig文件，按照Kconfig语法增加对应的选项；</span>**

**<span style="color:#33f">
 其次执行make menuconfig选择编译进内核或者不编译进内核，或者编译为模块，.config文件和autoconf.h文件会自动生成；</span>**

<span style="color:#33f">**最后修改对应目录下的makefile文件完成编译选项的添加；**</span>

<span style="color:#33f">**最后的最后执行make zImage命令进行编译。**</span>

<span style="color:red">**三、具体实例**</span>

**<span style="color:#33f">下面我们以前面做过的模块实验为例，讲解如何通过make menuconfig机制将前面单独编译的模块编译进内核或编译为模块</span>**

**<span style="color:#33f">假设我已经有了这么一个驱动：</span>**

<span style="color:red">
**modules.c**</span>

- <span style="color:grey">#include <linux/module.h> /\*module_init()\*/ </span>
- <span style="color:grey">#include <linux/kernel.h> /\* printk() \*/ </span>
- <span style="color:grey"> #include <linux/init.h> /\* __init __exit \*/ </span>
- <span style="color:grey"> #define DEBUG //open debug message </span>
- <span style="color:grey">#ifdef DEBUG </span>
- <span style="color:grey">#define PRINTK(fmt, arg...) printk(KERN_WARNING fmt, ##arg) </span>
- <span style="color:grey">#else </span>
- <span style="color:grey">#define PRINTK(fmt, arg...) printk(KERN_DEBUG fmt, ##arg) </span>
- <span style="color:grey">#endif </span>
- <span style="color:#008200">/\* Module Init & Exit function \*/</span>
- **<span style="color:#069">static</span>** **<span style="color:#2e8b57">int</span>** __init myModule_init(**<span style="color:#069">void</span>**)
- {
- <span style="color:#008200">/\* Module init code \*/</span>
- PRINTK(<span style="color:#00f">"myModule_init\n"</span>);
- **<span style="color:#069">return</span>** 0;
- }
- **<span style="color:#069">static</span>** **<span style="color:#069">void</span>** __exit myModule_exit(**<span style="color:#069">void</span>**)
- {
- <span style="color:#008200"> /\* Module exit code \*/</span>
- PRINTK(<span style="color:#00f">"myModule_exit\n"</span>);
- **<span style="color:#069"> return</span>**;
- }
- module_init(myModule_init);
- module_exit(myModule_exit);
- MODULE_AUTHOR(<span style="color:#00f">"dengwei"</span>); <span style="color:#008200">/\*模块作者，可选\*/</span>
- MODULE_LICENSE(<span style="color:#00f">"GPL"</span>); <span style="color:#008200">/\*模块许可证明，描述内核模块的许可权限，必须\*/</span>
- MODULE_DESCRIPTION(<span style="color:#00f">"A simple Hello World Module"</span>); <span style="color:#008200">/\*模块说明，可选\*/</span>

**<span style="color:#33f">Step1：将 modules.c拷到drivers/char/目录下(这个文件夹一般存放常见的字符驱动)</span>**

**<span style="color:#33f">Step2: vi driver/char/Kconfig,在</span>**

**<span style="color:#33f"> config DEVKMEM后添加以下信息</span>**

**<span style="color:#33f">config MODULES tristate "modules device support" default y help Say Y here,the modules will be build in kernel. Say M here,the modules willbe build to modules. Say N here,there will be nothing to be do. </span>**

**<span style="color:#33f">Step3：make menuconfig</span>**

**<span style="color:#33f">Device driver-character devices</span>**

**<span style="color:#33f"> [\*]modules device suppor</span>**

**<span style="color:#33f">Step4:vi driver/char/Makefile，在js-rtc后添加</span>**

**<span style="color:#33f">obj-$(CONFIG_MODULES)+= modules.o </span>**

**<span style="color:#33f">CONFIG_MODULES 必须跟上面的Kconfig中保持一致，系统会自动添加CONFIG_前缀</span>**

<span style="color:#33f">**modules.o必须跟你加入的.c文件名一致**</span>

<span style="color:red">最后执行：make zImage modules就会被编译进内核中
</span>

<span style="color:red">第三步：</span>

**<span style="color:#33f">Step3：make menuconfig</span>**

**<span style="color:#33f">Device driver-character devices</span>**

**<span style="color:#33f"> [M]modules device suppor</span>**

**<span style="color:#33f">把星号在配置界面通过空格改为M，最后执行make modules，在driver/char/目录下会生成一个modules.ko文件</span>**

<span style="color:red">
跟我们前面讲的单独编译模块效果一样，也会生成一个模块，将它考入开发板执行insmod moudles.ko，即可将生成的模块插入内核使用。</span>

<span style="color:red">PS：自己的看法</span>

Linux内核的make menuconfig实际上是执行了：

scripts/kconfig/mconf arch/mips/Kconfig

mconf表示是menuconfig，如果是用基于QT的配置工具，则执行的将会是qconf，arch/mips/Kconfig是要读取的Kconfig文件，这个会因平台而异，这里因为针对的是MIPS平台，故读取的是arch/mips/目录下的Kconfig文件。

如果Linux源码树顶层目录下已有.config文件，make menuconfig则从.config文件取默认参数，如果没有.config则从各个Kconfig中取默认参数。

mconf会把用户的选择保存到Linux源码树顶层目录的.config文件中，然后解析该文件并将解析结果写入到include/linux/autoconf.h中。include/linux/autoconf.h将会被include/linux/config.h包含，因此，需要关心配置情况的内核源文件只需要#include <linux/config.h>即可。

mconf解析.config文件时所采用的规则具体要仔细分析mconf.c源代码。
