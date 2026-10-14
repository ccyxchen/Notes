# C语言中的宽字符_buzhifou01的博客-程序员宝宝_c语言宽字符 - 程序员宝宝

# 前言

```
  我们接触的系统(Windows、Linux、Unix)都是用C语言编写的，可想而知学好C语言有多么重要，我们在日常写代码的过程中，大部分接触的是ASCII字符，那么对于字符变量，我们常用的数据类型是char，但是对于中文字符，用char变量就不行了，那么就需要使用宽字符了。
```

# 字符与宽字符

下面显示的常用的字符与宽字符，及与它们相关的函数。

![在这里插入图片描述](img/C%E8%AF%AD%E8%A8%80%E4%B8%AD%E7%9A%84%E5%AE%BD%E5%AD%97%E7%AC%A6_buzhifou01%E7%9A%84%E5%8D%9A%E5%AE%A2-%E7%A8%8B%E5%BA%8F%E5%91%98%E5%AE%9D%E5%AE%9D_c%E8%AF%AD%E8%A8%80%E5%AE%BD%E5%AD%97%E7%AC%A6%20-%20%E7%A8%8B%E5%BA%8F%E5%91%98%E5%AE%9D%E5%AE%9D-01.jpg)

# 宽字符语法及使用

1.使用宽字符变量定义中文变量之前，先要使用setlocale函数来声明中国地域，他的作用相当于在控制台窗口设置好当前代码页的编码方式。

```c
#include<stdio.h>
#include<locale.h>
int main()
{

   setlocale(LC_ALL,"");
   return 0;
}
```

![在这里插入图片描述](img/C%E8%AF%AD%E8%A8%80%E4%B8%AD%E7%9A%84%E5%AE%BD%E5%AD%97%E7%AC%A6_buzhifou01%E7%9A%84%E5%8D%9A%E5%AE%A2-%E7%A8%8B%E5%BA%8F%E5%91%98%E5%AE%9D%E5%AE%9D_c%E8%AF%AD%E8%A8%80%E5%AE%BD%E5%AD%97%E7%AC%A6%20-%20%E7%A8%8B%E5%BA%8F%E5%91%98%E5%AE%9D%E5%AE%9D-02.jpg)

2.对于中文字符及中文字符串，我们需要使用wchar_t数据类型来定义

```c
  wchar_t c=L'我';
  wchar_t s[]=L"我是中国人";
```

3.宽字符串的输入与输出

```c
#include<stdio.h>
#include<locale.h>
int main()
{

   setlocale(LC_ALL,"");
   wchar_t in[250];
   wscanf(L"%s",in);
   wprintf(L"%s\n",in);
   wchar_t s[]=L"我是一只小鸟";
   wprintf(L"%s\n",s);
   return 0;
}
```

![在这里插入图片描述](img/C%E8%AF%AD%E8%A8%80%E4%B8%AD%E7%9A%84%E5%AE%BD%E5%AD%97%E7%AC%A6_buzhifou01%E7%9A%84%E5%8D%9A%E5%AE%A2-%E7%A8%8B%E5%BA%8F%E5%91%98%E5%AE%9D%E5%AE%9D_c%E8%AF%AD%E8%A8%80%E5%AE%BD%E5%AD%97%E7%AC%A6%20-%20%E7%A8%8B%E5%BA%8F%E5%91%98%E5%AE%9D%E5%AE%9D-03.jpg)

# 宽字符串简单操作

```c
#include<stdio.h>
#include<locale.h>
#include<stdlib.h>
#include<string.h>
int main()
{

    setlocale(LC_ALL,"");


    wchar_t s1[]=L"我是一只小鸟";
    wchar_t s2[]=L"我是一个人";
    wchar_t s3[250];
    wcscat(s1, s2); //把s2宽字符串拼接到s1的后面
    wprintf(L"%s\n",s1);

    wchar_t s4[]=L"我是一只小鸟";
    wchar_t s5[]=L"我是一只小鸟";
    if(!wcscmp(s4,s5)) //比较s4和s5是否相同
        wprintf(L"相同\n");
    else
        wprintf(L"不同\n");

   wcscpy(s3,s1); //把s1复制到s3中

   wprintf(L"%s\n",s3);

   printf("%d\n",wcslen(s3)); //输出宽字符串的长度
   return 0;
}
```

![在这里插入图片描述](img/C%E8%AF%AD%E8%A8%80%E4%B8%AD%E7%9A%84%E5%AE%BD%E5%AD%97%E7%AC%A6_buzhifou01%E7%9A%84%E5%8D%9A%E5%AE%A2-%E7%A8%8B%E5%BA%8F%E5%91%98%E5%AE%9D%E5%AE%9D_c%E8%AF%AD%E8%A8%80%E5%AE%BD%E5%AD%97%E7%AC%A6%20-%20%E7%A8%8B%E5%BA%8F%E5%91%98%E5%AE%9D%E5%AE%9D-04.jpg)
