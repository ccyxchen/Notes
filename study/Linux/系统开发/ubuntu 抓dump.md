# ubuntu 抓dump
## 参考资料
1、kernel kexec 文档
[kdump.html](https://www.kernel.org/doc/html/v6.2/admin-guide/kdump/kdump.html)
[kernel_crash_dump_guide](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/7/html/kernel_administration_guide/kernel_crash_dump_guide)
2、makedumpfile文档
[makedumpfile](https://github.com/makedumpfile/makedumpfile)
3、crash文档
[crash help](https://crash-utility.github.io/)

## kernel原理和代码分析

kernel文档摘要：
The kexec -p command loads the dump-capture kernel into this reserved memory.
