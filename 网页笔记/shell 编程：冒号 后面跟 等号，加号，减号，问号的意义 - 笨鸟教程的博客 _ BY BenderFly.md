# shell 编程：冒号 后面跟 等号，加号，减号，问号的意义 - 笨鸟教程的博客 | BY BenderFly

# shell 编程：冒号 后面跟 等号，加号，减号，问号的意义

## 缺省值（:-）

${var:-string}
若变量var为空或者未定义,则用在命令行中用string来替换${var:-string}
否则变量var不为空时,则用变量var的值来替换${var:-string}

```bash
$ COMPANY=
$ printf "%s\n" "${COMPANY:-Unknown Company}"
Unknown Company
$ echo $COMPANY
```

变量的实际值保持不变。

## 指定缺省值（:=）

如果变量后面跟着冒号和等号，则给空变量指定一个缺省值。

```bash
$ printf "%s\n" "${COMPANY:=Nightlight Inc.}"
Nightlight Inc.
$ printf "%s\n" "${COMPANY}”
Nightlight Inc.
```

变量的实际值已经改变了。 比较${var:-string}和${var:=string} 后者发现$var为空时,把string赋值给了var 后者是一种赋值默认值的常见做法

## 变量是否存在检查（:?）

替换规则:若变量var不为空,则用变量var的值来替换${var:?string} 

若变量var为空,则把string输出到标准错误中,并从脚本中退出。 

可利用此特性来检查是否设置了变量的值

根据变量是否存在，显示不同的信息。信息不是必选的。 `printf "Company is %s\n" "${COMPANY:?Error: Company has notbeen defined—aborting}" `

## 覆盖缺省值(:+)

${var:+string}
规则和${var:-string},${var:=string}的完全相反
即只有当var不是空的时候才替换成string,若var为空时则不替换或者说是替换成变量var的值,即空值

```bash
$ COMPANY="Nightlight Inc."
$ printf "%s\n" "${COMPANY:+Company has been overridden}"
Company has been overridden
```

## 替换部分字符串（:n）

如果变量后面跟着一个冒号和数字，则返回该数字开始的一个子字符串，如果后面还跟着一个冒号和数字。则第一个数字表示开始的字符，后面数字表示字符的长度。

```bash
$ printf "%s\n" "${COMPANY:5}"
light Inc.
$ printf "%s\n" "${COMPANY:5:5}"
light
```

根据模板删除字串（%，#，%%，##）
#删除左边,%删除右边
如果变量后面跟着井号，则返回匹配模板被删除后的字串。一个井号为最小可能性的匹配，两个井号为自大可能性的匹配。表达式返回模板右边的字符。

```bash
$ COMPANY="Nightlight Inc."
$ printf "%s\n" "${COMPANY#Ni*}"
ghtlight Inc.
$ printf "%s\n" "${COMPANY##Ni*}"

$ printf "%s\n" "${COMPANY##*t}"
Inc.
$ printf "%s\n" "${COMPANY#*t}"
light Inc.

#使用百分号，表达式返回模板左边的字符
$ printf "%s\n" "${COMPANY%t*}"
Nightligh
$ printf "%s\n" "${COMPANY%%t*}"
Nigh
```

案例:
获取文件名和后缀名

```bash
$ f=file.tar.gz
$ echo ${f##*.}
gz
$ echo ${f%%.*}
file

#假设我们定义了一个变量为：
file=/dir1/dir2/dir3/my.file.txt

#可以用${ }分别替换得到不同的值：
${file#*/}：删掉第一个 / 及其左边的字符串：dir1/dir2/dir3/my.file.txt
${file##*/}：删掉最后一个 /  及其左边的字符串：my.file.txt
${file#*.}：删掉第一个 .  及其左边的字符串：file.txt
${file##*.}：删掉最后一个 .  及其左边的字符串：txt
${file%/*}：删掉最后一个  /  及其右边的字符串：/dir1/dir2/dir3
${file%%/*}：删掉第一个 /  及其右边的字符串：(空值)
${file%.*}：删掉最后一个  .  及其右边的字符串：/dir1/dir2/dir3/my.file
${file%%.*}：删掉第一个  .   及其右边的字符串：/dir1/dir2/dir3/my
```

记忆的方法为： #是 去掉左边（键盘上#在 $ 的左边） %是去掉右边（键盘上% 在$ 的右边） 单一符号是最小匹配；两个符号是最大匹配

## 使用模板进行子字符串的替换（//）

如果变量后只有一个斜杠，则两个斜杠中间的字符串是要被替换的字符串，而第二个斜杠后面的字符串是要替换的字符串。如果变量后面跟着两个斜杠，则所有出现在两个斜杠中间的字符都要被替换为最后一个斜杠后面的字符。

```bash
$ printf "%s\n" "${COMPANY/Inc./Incorporated}"
Nightlight Incorporated
$ printf "You are the I in %s\n" "${COMPANY//i/I}"
You are the I in NIghtlIght Inc.
```

如果模板以#号开始，则匹配以模板开始的字符，如果模板以%号结尾(在centos7上测试不生效)，则匹配以模板结尾的字符。

```bash
$ COMPANY="NightLight Night Lighting Inc."
$ printf "%s\n" "$COMPANY"
NightLight Night Lighting Inc.
$ printf "%s" "${COMPANY//Night/NIGHT}"
NIGHTLight NIGHT Lighting Inc.
$ printf "%s" "${COMPANY//#Night/NIGHT}"
NIGHTLight Night Lighting Inc.
```

**如果没有指定新的值，则匹配的字符会被删除。**

```bash
$ COMPANY="Nightlight Inc."
$ printf "%s\n" "${COMPANY/light}"
Night Inc.
```

也可以使用范围符号。例如：删除所有字符串中的标点符号，使用范围[:punct:]。

```bash
$ printf "%s" "${COMPANY//[[:punct:]]}"
Nightlight Inc
```

使用*号或@符号替换变量会替换shell脚本中所有的参数，同样，在数组中使用*号或@符号也会替换数组中的所有元素

- [Previous 在CentOS/RHEL上设置SSH免密码登录](https://handerfly.github.io/linux/2019/04/03/ssh-%E5%85%8D%E5%AF%86%E7%99%BB%E5%BD%95/)
- [Next shell编程技巧](https://handerfly.github.io/shell/2019/04/04/Shell%E7%BC%96%E7%A8%8B%E6%8A%80%E5%B7%A7/)

[0](https://handerfly.github.io/shell/2019/04/03/shell%E7%BC%96%E7%A8%8B%E5%86%92%E5%8F%B7%E5%8A%A0-%E7%AD%89%E5%8F%B7-%E5%8A%A0%E5%8F%B7-%E5%87%8F%E5%8F%B7-%E9%97%AE%E5%8F%B7/null) 条评论

未登录用户

Error: Bad credentials.

[支持 Markdown 语法](https://guides.github.com/features/mastering-markdown/)

预览

使用 GitHub 登录

来做第一个留言的人吧！

[CATALOG](https://handerfly.github.io/shell/2019/04/03/shell%E7%BC%96%E7%A8%8B%E5%86%92%E5%8F%B7%E5%8A%A0-%E7%AD%89%E5%8F%B7-%E5%8A%A0%E5%8F%B7-%E5%87%8F%E5%8F%B7-%E9%97%AE%E5%8F%B7/#)

- [shell 编程：冒号 后面跟 等号，加号，减号，问号的意义](https://handerfly.github.io/shell/2019/04/03/shell%E7%BC%96%E7%A8%8B%E5%86%92%E5%8F%B7%E5%8A%A0-%E7%AD%89%E5%8F%B7-%E5%8A%A0%E5%8F%B7-%E5%87%8F%E5%8F%B7-%E9%97%AE%E5%8F%B7/#shell-%E7%BC%96%E7%A8%8B%E5%86%92%E5%8F%B7-%E5%90%8E%E9%9D%A2%E8%B7%9F-%E7%AD%89%E5%8F%B7%E5%8A%A0%E5%8F%B7%E5%87%8F%E5%8F%B7%E9%97%AE%E5%8F%B7%E7%9A%84%E6%84%8F%E4%B9%89)
- [缺省值（:-）](https://handerfly.github.io/shell/2019/04/03/shell%E7%BC%96%E7%A8%8B%E5%86%92%E5%8F%B7%E5%8A%A0-%E7%AD%89%E5%8F%B7-%E5%8A%A0%E5%8F%B7-%E5%87%8F%E5%8F%B7-%E9%97%AE%E5%8F%B7/#%E7%BC%BA%E7%9C%81%E5%80%BC-)
- [指定缺省值（:=）](https://handerfly.github.io/shell/2019/04/03/shell%E7%BC%96%E7%A8%8B%E5%86%92%E5%8F%B7%E5%8A%A0-%E7%AD%89%E5%8F%B7-%E5%8A%A0%E5%8F%B7-%E5%87%8F%E5%8F%B7-%E9%97%AE%E5%8F%B7/#%E6%8C%87%E5%AE%9A%E7%BC%BA%E7%9C%81%E5%80%BC)
- [变量是否存在检查（:?）](https://handerfly.github.io/shell/2019/04/03/shell%E7%BC%96%E7%A8%8B%E5%86%92%E5%8F%B7%E5%8A%A0-%E7%AD%89%E5%8F%B7-%E5%8A%A0%E5%8F%B7-%E5%87%8F%E5%8F%B7-%E9%97%AE%E5%8F%B7/#%E5%8F%98%E9%87%8F%E6%98%AF%E5%90%A6%E5%AD%98%E5%9C%A8%E6%A3%80%E6%9F%A5)
- [覆盖缺省值(:+)](https://handerfly.github.io/shell/2019/04/03/shell%E7%BC%96%E7%A8%8B%E5%86%92%E5%8F%B7%E5%8A%A0-%E7%AD%89%E5%8F%B7-%E5%8A%A0%E5%8F%B7-%E5%87%8F%E5%8F%B7-%E9%97%AE%E5%8F%B7/#%E8%A6%86%E7%9B%96%E7%BC%BA%E7%9C%81%E5%80%BC)
- [替换部分字符串（:n）](https://handerfly.github.io/shell/2019/04/03/shell%E7%BC%96%E7%A8%8B%E5%86%92%E5%8F%B7%E5%8A%A0-%E7%AD%89%E5%8F%B7-%E5%8A%A0%E5%8F%B7-%E5%87%8F%E5%8F%B7-%E9%97%AE%E5%8F%B7/#%E6%9B%BF%E6%8D%A2%E9%83%A8%E5%88%86%E5%AD%97%E7%AC%A6%E4%B8%B2n)
- [使用模板进行子字符串的替换（//）](https://handerfly.github.io/shell/2019/04/03/shell%E7%BC%96%E7%A8%8B%E5%86%92%E5%8F%B7%E5%8A%A0-%E7%AD%89%E5%8F%B7-%E5%8A%A0%E5%8F%B7-%E5%87%8F%E5%8F%B7-%E9%97%AE%E5%8F%B7/#%E4%BD%BF%E7%94%A8%E6%A8%A1%E6%9D%BF%E8%BF%9B%E8%A1%8C%E5%AD%90%E5%AD%97%E7%AC%A6%E4%B8%B2%E7%9A%84%E6%9B%BF%E6%8D%A2)

[FEATURED TAGS](https://handerfly.github.io/tags/)

[Python](https://handerfly.github.io/tags/#Python)

[Linux](https://handerfly.github.io/tags/#Linux)

[运维](https://handerfly.github.io/tags/#%E8%BF%90%E7%BB%B4)

[Shell](https://handerfly.github.io/tags/#Shell)

[Django](https://handerfly.github.io/tags/#Django)

[开发技巧](https://handerfly.github.io/tags/#%E5%BC%80%E5%8F%91%E6%8A%80%E5%B7%A7)

[Elasticsearch](https://handerfly.github.io/tags/#Elasticsearch)

[ELK](https://handerfly.github.io/tags/#ELK)

[Ansible](https://handerfly.github.io/tags/#Ansible)

FRIENDS

- [健身网](https://www.benderfly.com/)
- [BD](http://www.baidu.com/)
