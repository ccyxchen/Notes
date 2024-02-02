# codeviz编译gcc-7.4

## docker ubuntu-14.04 编译gcc-7.4

安装编译工具链和库

```Shell
apt-get install gcc-4.8 g++-4.8
apt-get install libgcc-4.8-dev GNAT binutils
apt-get install mawk gzip bzip2 make tar Perl m4 automake gettext gperf DejaGnu Expect Tcl autogen guile-1.8 Flex Texinfo TeXlive python-sphinx subversion SSH diffutils patch
```
../gcc-7.4.0/configure --prefix=/home/bin/codeviz/compilers/gcc-graph --enable-shared --enable-languages=c,c++  --disable-multilib

make bootstrap 2>&1 | tee cc.log