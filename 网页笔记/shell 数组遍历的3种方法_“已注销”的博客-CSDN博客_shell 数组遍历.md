# (172条消息) shell 数组遍历的3种方法_“已注销”的博客-CSDN博客_shell 数组遍历

欢迎参与个人独立开发的阅时即查web APP公测

![在这里插入图片描述](img/(172%E6%9D%A1%E6%B6%88%E6%81%AF)%20shell%20%E6%95%B0%E7%BB%84%E9%81%8D%E5%8E%86%E7%9A%843%E7%A7%8D%E6%96%B9%E6%B3%95_%E2%80%9C%E5%B7%B2%E6%B3%A8%E9%94%80%E2%80%9D%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2_shell%20%E6%95%B0%E7%BB%84%E9%81%8D%E5%8E%86-01.jpg)

![在这里插入图片描述](img/(172%E6%9D%A1%E6%B6%88%E6%81%AF)%20shell%20%E6%95%B0%E7%BB%84%E9%81%8D%E5%8E%86%E7%9A%843%E7%A7%8D%E6%96%B9%E6%B3%95_%E2%80%9C%E5%B7%B2%E6%B3%A8%E9%94%80%E2%80%9D%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2_shell%20%E6%95%B0%E7%BB%84%E9%81%8D%E5%8E%86-02.jpg)

有兴趣也请关注个人微信公众号

![在这里插入图片描述](img/(172%E6%9D%A1%E6%B6%88%E6%81%AF)%20shell%20%E6%95%B0%E7%BB%84%E9%81%8D%E5%8E%86%E7%9A%843%E7%A7%8D%E6%96%B9%E6%B3%95_%E2%80%9C%E5%B7%B2%E6%B3%A8%E9%94%80%E2%80%9D%E7%9A%84%E5%8D%9A%E5%AE%A2-CSDN%E5%8D%9A%E5%AE%A2_shell%20%E6%95%B0%E7%BB%84%E9%81%8D%E5%8E%86-03.jpg)

shell[数组](https://so.csdn.net/so/search?q=%E6%95%B0%E7%BB%84&spm=1001.2101.3001.7020)的基本知识请参阅我的上一篇博客[shell 数组](http://blog.csdn.net/lockey23/article/details/74625636) 首先创建一个数组 array=( A B C D 1 2 3 4) ###1.标准的for循环

```c
for(( i=0;i<${#array[@]};i++)) do
#${#array[@]}获取数组长度用于循环
echo ${array[i]};
done;
```

###2.for … in
 [遍历](https://so.csdn.net/so/search?q=%E9%81%8D%E5%8E%86&spm=1001.2101.3001.7020)（不带数组下标）：

```
for element in ${array[@]}
#也可以写成for element in ${array[*]}
do
echo $element
done
```

遍历（带数组下标）：

```c
for i in "${!arr[@]}";
do
    printf "%s\t%s\n" "$i" "${arr[$i]}"
done
```

###3.While循环法：

```
i=0
while [ $i -lt ${#array[@]} ]
#当变量（下标）小于数组长度时进入循环体
do
    echo ${ array[$i] }
    #按下标打印数组元素
    let i++
done
```
