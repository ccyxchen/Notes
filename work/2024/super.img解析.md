# super.img解析

由于上面命令生成super.img中带有--sparse选项，所以生成的super.img为sparse image格式，在解析前需要使用工具simg2img将其转换成raw格式。

simg2img out/target/product/productName/super.img out/super_raw.img
