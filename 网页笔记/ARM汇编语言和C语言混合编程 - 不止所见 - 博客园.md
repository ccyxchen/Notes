# ARM汇编语言和C语言混合编程 - 不止所见 - 博客园

ARM汇编语言和C语言混合编程

**ATPCS规则**体现了一种模块化设计的思想，其基本内容是C模块(函数)和汇编模块(函数)相互调用的一套规则（C51中也有类似的一套规则）。我感觉比在线汇编功能强大（不用有很多忌讳），条理更清楚（很简单的几条规则）。

ATPCS规则内容：
1)寄存器的使用规则
1、子程序之间通过寄存器r0~r3来传递参数，当参数个数多于4个时，使用堆栈来传递参数。此时r0~r3可记作A1~A4。
2、在子程序中，使用寄存器r4~r11保存局部变量。因此当进行子程序调用时要注意对这些寄存器的保存和恢复。此时r4~r11可记作V1~V8。
3、寄存器r12用于保存堆栈指针SP，当子程序返回时使用该寄存器出栈，记作IP。
4、寄存器r13用作堆栈指针，记作SP。寄存器r14称为链接寄存器，记作LR。该寄存器用于保存子程序的返回地址。
5、寄存器r15称为程序计数器，记作PC。
2)堆栈的使用规则
ATPCS规定堆栈采用满递减类型(FD,Full Descending)，即堆栈通过减小存储器地址而向下增长，堆栈指针指向内含有效数据项的最低地址。
3)参数的传递规则
1、整数参数的前4个使用r0~r3传递，其他参数使用堆栈传递；浮点参数使用编号最小且能够满足需要的一组连续的FP寄存器传递参数。
2、子程序的返回结果为一个32位整数时，通过r0返回；返回结果为一个64位整数时，通过r0和r1返回；依此类推。结果为浮点数时，通过浮点运算部件的寄存器F0、D0或者S0返回。

比较有条理，很清楚，我举两个例子：

**1.汇编主程序调用C子程序**
汇编程序的书写要遵循ATPCS规则，以保证程序调用时参数正确传递。在汇编程序中调用C程序的方法为：首先在汇编程序中使用IMPORT伪指令或者extern事先声明将要调用的C语言函数；然后通过BL指令来调用C函数。
例如在一个C源文件中定义了如下求和函数：
int add(int x,int y){
 return(x+y);
}
调用add()函数的汇编程序结构如下：
area main,code,readonly ;代码段
entry ;声明程序入口
code32 ;32位ARM指令
IMPORT add 或者extern add;声明要调用的C函数
start
……
MOV r0,1
MOV r1,2
BL add ;调用C函数add
……
end
当进行函数调用时，使用r0和r1实现参数传递，返回结果由r0带回。函数调用结束后，r0的值变成3。

**2.C主程序调用汇编子程序**
C程序调用汇编程序时，汇编程序的书写也要遵循ATPCS规则，以保证程序调用时参数正确传递。在C程序中调用汇编子程序的方法为：首先在汇编程序中使用EXPORT伪指令声明被调用的子程序，表示该子程序将在其他文件中被调用；然后在C程序中使用extern关键字声明要调用的汇编子程序为外部函数。
例如在一个汇编源文件中定义了如下求和函数：
EXPORT add ;声明add子程序将被外部函数调用
 ……
add ;求和子程序add
 global add ；声明
 ADD r0,r0,r1
 MOV pc,lr
 ……
在一个C程序的main()函数中对add汇编子程序进行了调用：
extern int add (int x,int y); //声明add为外部函数
void main(){
 int a=1,b=2,c;
 c=add(a,b); //调用add子程序
 ……
}
当main()函数调用add汇编子程序时，变量a、b的值会给了r0和r1，返回结果由r0带回，并赋值给变量c。函数调用结束后，变量c的值变成3。

**3、C程序中内嵌汇编语句**在C语言中内嵌汇编语句可以实现一些高级语言不能实现或者不容易实现的功能。对于时间紧迫的功能也可以通过在C语言中内嵌汇编语句来实现。内嵌的汇编器支持大部分ARM指令和Thumb指令，但是不支持诸如直接修改PC实现跳转的底层功能，也不能直接引用C语言中的变量。
内嵌汇编:在C和C＋＋语言中嵌入汇编语言可以实现一些高级语言中没有的功能。
语法
__asm__( ;注意:前面是两个“_”
 “instruction 
 ...
 instruction” 
);//Linux gcc中支持
__asm{
 instruction
 ...
 instruction
}; //ADS中支持
asm(“instruction[; instruction]”); //ARM C＋＋中使用
ARM内嵌汇编语法
asm(
 汇编语句模板: 
 输出部分: 
 输入部分: 
 修改部分
)；
比如： asm("mov %0, %1, ror #1" :"=r" (result) : "r" (value));
共四个部分：汇编语句模板，输出部分，输入部分，破坏描述部分，各部分使用“:”格开，汇编语句模板必不可少，其他三部分可选，如果使用了后面的部分，而前面部分为空，也需要用“:”格开，相应部分内容为空。例如：
__asm__ __volatile__(
 "CLI":
 :"memory"
)；

示例：/\* main.c \*/
void __main(void)
{
 int var=0xAA;
 __asm //内嵌汇编标识
 {
 MOV R1,var
 CMP R1,#0xAA
 }
 while(1);
}

扩展知识：**汇编语句模板：**
汇编语句模板由汇编语句序列组成，语句之间使用“；”、“\n”或“\n\t”分开。指令中的操作数可以使用占位符引用C语言变量，操作数占位符最多10个，名称如下：%0，%1…，%9。
The assembler instructions, defined as asingle string constant: "mov %0, %1, ror #1"
输出部分：输出部分描述输出操作数，不同的操作数描述符之间用逗号格开，每个操作数描述符由限定字符串和C语言变量组成。每个输出操作数的限定字符串必须包含“=”表示他是一个输出操作数。
"=r" (result)
输入部分：输入部分描述输入操作数，不同的操作数描述符之间使用逗号格开，每个操作数描述符由限定字符串和C语言表达式或者C语言变量组成。
"r" (value)
修改部分（modify）：这部分常常以“memory”为约束条件，以表示操作完成后内存中的内容已有改变，如果原来某个寄存器的内容来自内存，那么现在内存中这个单元的内容已经改变。
asm(code: outputoperandlist: inputoperandlist: clobberlist);
asm("mov %0, %1, ror #1" :"=r" (result) : "r" (value));
%0 refers to "=r" (result) and %1 refers to "r" (value) 
产生的汇编语句：The compiler selected registerr3 for bit rotation.
It could have selected any other register,though.
ldr r3, [sp, #0] 
mov r3, r3, ror #1 
str r3, [sp, #4] 
You can add the volatile attribute to theasm statement to instruct the compiler not to optimize your assembler code. 
asm volatile("mov %0, %1, ror#1" : "=r" (result) : "r" (value)); 
限制字符：作用是指示编译器如何处理其后的C语言变量与指令操作数之间的关系，例如是将变量放在寄存器中还是放在内存中等，
字母 含义
m,v,o 表示内存单元
R 表示任何通用寄存器
Q 表示寄存器eax, ebx, ecx,edx之一
I, h 表示直接操作数
E, F 表示浮点数
G 表示“任意”
a,b,c,d 表示要求使用寄存器eax/ax/al, ebx/bx/bl, ecx/cx/cl或edx/dx/dl
S, D 表示要求使用寄存器esi或edi
& 该输出操作数不能使用过河输入操作数相同的寄存器
% 该操作数可以和下一个数交换位置，如add
I 表示常数（0～31）

以上代码均在ARM ADS 1.2或者在linux环境中调试通过。
总结一下，在线汇编比较简洁，但功能有限，而且规则有点零碎；
ATPCS功能强大而且条理清楚，但需要单独在开一个模块；写代码时可以根据需要自由选择。

代码下载链接：[http://download.csdn.net/detail/klcf0220/5498399](http://download.csdn.net/detail/klcf0220/5498399)

参考链接：[http://guona081.blog.163.com/blog/static/847604692008102010366320/](http://guona081.blog.163.com/blog/static/847604692008102010366320/)

[ATPCS规范](http://www.cnblogs.com/luvi/archive/2008/04/30/1177961.html)：[http://www.cnblogs.com/luvi/archive/2008/04/30/1177961.html](http://www.cnblogs.com/luvi/archive/2008/04/30/1177961.html)

**喜欢开源，乐意分享的大神们，欢迎加入QQ群：176507146，你值的拥有哦！**
