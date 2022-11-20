# libjpeg-turbo功能简介

libjpeg-turbo库是libjpeg库的一个优化版本，主要用来压缩和解压jpg格式图片。可以参考库源码的readme进行学习。

## 交叉编译 libjpeg-turbo

参考库中的BUILDING.md文件，使用cmake 进行编译.

```Shell
# 创建构建目录
mkdir ~/workspace/open/libjpeg-turbo/build_dir

# 创建安装目录
mkdir /home/cyx/workspace/open/libjpeg-turbo/libjpeg_v2.0.0_arm-linux/

# 在构建目录编写cmake文件，指定交叉编译工具，安装目录等
#cmake内容如下
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

set(tools /home/cyx/workspace/Tools/arm-linux-gcc-4.3.2)
set(CMAKE_C_COMPILER ${tools}/bin/arm-linux-gcc)
set(CMAKE_CXX_COMPILER ${tools}/bin/arm-linux-g++)
set(CMAKE_INSTALL_PREFIX /home/cyx/workspace/open/libjpeg-turbo/libjpeg_v2.0.0_arm-linux/)

# 生成cmake编译环境，编译安装
 cmake -G"Unix Makefiles" -DCMAKE_TOOLCHAIN_FILE=arm_linux_setup.cmake ~/workspace/open/libjpeg-turbo/libjpeg-turbo_git/
 make 
 make install

```

## libjpeg库的使用

libjpeg库使用主要参考源码包的libjpeg.txt文件，里面有库的基本API介绍，example.txt中实现了压缩和解压的参考示例，
下面是实现解压显示jpg图片的简单程序

```c
int main(int argc, char *argv[])
{
    struct jpeg_decompress_struct cinfo;
    struct jpeg_error_mgr jerr;
    FILE *infile;
    JSAMPROW buffer;            /* Output row buffer */
    int row_stride;               /* physical row width in output buffer */
    int ret;
    int x, y;
   
    if(argc != 4)
    {
        printf("please enter jpeg file name\n");
        return 0;
    }

    x = atoi(argv[2]);
    y = atoi(argv[3]);

    ret = lcd_init("/dev/fb0");
    if(ret)
    {
        printf("lcd_init err\n");
        return -1;
    }

    lcd_clear_screen(0xff);

    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_decompress(&cinfo);

    if ((infile = fopen(argv[1], "rb")) == NULL) {
        fprintf(stderr, "can't open %s\n", argv[1]);
        exit(1);
    }
    jpeg_stdio_src(&cinfo, infile);

    jpeg_read_header(&cinfo, TRUE);

    printf("image_width: %d, image_height: %d\n", cinfo.image_width, cinfo.image_height);
    printf("num_components: %d\n", cinfo.num_components);

    //cinfo.out_color_space = JCS_RGB565;

    /* unsigned int scale_num, scale_denom
        Scale the image by the fraction scale_num/scale_denom.  Default is
        1/1, or no scaling.  Currently, the only supported scaling ratios
        are M/8 with all M from 1 to 16, or any reduced fraction thereof (such
        as 1/2, 3/4, etc.)  (The library design allows for arbitrary
        scaling ratios but this is not likely to be implemented any time soon.)
        Smaller scaling ratios permit significantly faster decoding since
        fewer pixels need be processed and a simpler IDCT method can be used.
    */
    printf("printf scale_num/scale_denom\n");
    scanf("%d/%d", &cinfo.scale_num, &cinfo.scale_denom);

    jpeg_start_decompress(&cinfo);

    printf("output_width: %d, output_height: %d\n", cinfo.output_width, cinfo.output_height);
    printf("out_color_components: %d\n", cinfo.out_color_components);
    printf("output_components: %d\n", cinfo.output_components);

    /* JSAMPLEs per row in output buffer */
    row_stride = cinfo.output_width * cinfo.output_components;
    /* Make a one-row-high sample array that will go away when done with image */
    buffer = malloc(row_stride * sizeof(JSAMPLE));

    while (cinfo.output_scanline < cinfo.output_height) {
        (void) jpeg_read_scanlines(&cinfo, &buffer, 1);
        /* Assume put_scanline_someplace wants a pointer and sample count. */

        //替换为自己的lcd显示函数
        //lcd_show_line(x , y + cinfo.output_scanline - 1, cinfo.output_width, cinfo.output_components, buffer);
    }

    jpeg_finish_decompress(&cinfo);
    jpeg_destroy_decompress(&cinfo);
    fclose(infile);

    return 0;
}

```
