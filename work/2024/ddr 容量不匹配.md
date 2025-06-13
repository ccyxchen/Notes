# mtk 平台DDR 容量识别和初始化流程

mtk 对ddr的容量识别是在preloader的mblock模块上实现，其中会通过ddr的
mblock确定硬件可用的总容量，并且可以在代码上限制要初始化的容量大小，
如果限制大小小于总容量，系统就只会用到ddr的部分空间。

## MT6739/MT8765WA 机制

```txt
CUSTOM_CONFIG_MAX_DRAM_SIZE: 0x0000000080000000
total_dram_size: 0x00000000C0000000, max_dram_size: 0x0000000080000000
dump mblock info 
mblock[0] start=0000000040000000 size=0000000080000000
```

对DDR rank的解析：
AI生成///
在 DDR（Double Data Rate）内存中，一个 rank 是一个逻辑组合，由一个或多个存储芯片组成。
每个存储芯片都有自己的数据引脚和控制引脚。在 DDR内存中，rank 是指一组存储芯片，它们同
时响应内存控制器的请求，从而提供更大的内存容量和更高的带宽。

举例来说，一个 DDR内存条可能包含多个存储 rank，每个 rank 由一组存储芯片组成。每个 rank 
可以被看作是一个独立的内存模块，它们可以同时响应内存控制器的读写请求，从而提高内存访问的并行度和带宽。

在实际的内存配置中，您可能会看到术语 "single-rank"、"dual-rank" 或 "quad-rank"，它们分别
表示内存模块包含一个、两个或四个 rank。这些术语通常用于描述内存模块的性能和配置。

当前使用的LPDDR4X内存一般有1个或2个rank.

```C
//vendor/mediatek/proprietary/bootable/bootloader/preloader/platform/common/mblock/mblock_v2.c
221  void setup_mblock_info(mblock_info_t *mblock_info, dram_info_t *orig_dram_info,
222          mem_desc_t *lca_reserved_mem)

230   for (i = 0; i < bootarg.orig_dram_info.rank_num; i++) {
231    total_dram_size +=
232     bootarg.orig_dram_info.rank_info[i].size;
233   }

237   max_dram_size = get_config_max_dram_size();

//初始化mblock_info信息，mblock_info是代码中要使用的ddr mblock 
/*
242    * non-4GB mode case
243    */
244   /* we do some DRAM size fixup here base on orig_dram_info */
245   for (i = 0; i < bootarg.orig_dram_info.rank_num; i++) {
246    size += bootarg.orig_dram_info.rank_info[i].size;
247    bootarg.mblock_info.mblock[i].start =
248     bootarg.orig_dram_info.rank_info[i].start;
249    bootarg.mblock_info.mblock[i].rank = i; /* setup rank */
250    if (size <= max_dram_size) {
251     bootarg.mblock_info.mblock[i].size =
252      bootarg.orig_dram_info.rank_info[i].size;
253    } else {
254     /* max dram size reached */
255     size -= bootarg.orig_dram_info.rank_info[i].size;
256     bootarg.mblock_info.mblock[i].size =
257      max_dram_size - size;
258     /* get lca_reserved_mem info */
259     bootarg.lca_reserved_mem.start = bootarg.mblock_info.mblock[i].start
260             + bootarg.mblock_info.mblock[i].size;
261     if (bootarg.mblock_info.mblock[i].size) {
262      bootarg.mblock_info.mblock_num++;
263     }
264     break;
265    }
266  
267    if (bootarg.mblock_info.mblock[i].size) {
268     bootarg.mblock_info.mblock_num++;
269    }
270   }

272   print("total_dram_size: 0x%llx, max_dram_size: 0x%llx\n",
273       total_dram_size, max_dram_size);
274   print("dump mblock info \n");
275   for (i = 0;i < bootarg.mblock_info.mblock_num;i++)
276    print("mblock[%d] start=%llx size=%llx\n", i,
277     bootarg.mblock_info.mblock[i].start, bootarg.mblock_info.mblock[i].size);
278  

194  u64 get_config_max_dram_size()
195  {
196   u64 max_dram_size = -1; /* max value */
197   char *doe_max_dram_size_config = 0;
198   u64 doe_max_dram_size;
199   int size_shift = 28; /* 256 MB */
200  
201  #ifdef CUSTOM_CONFIG_MAX_DRAM_SIZE
202   max_dram_size = CUSTOM_CONFIG_MAX_DRAM_SIZE;
203  #endif
204  #ifdef MTK_DOE_CONFIG_ENV_SUPPORT
205   doe_max_dram_size_config = dconfig_getenv("DOE_CUSTOM_CONFIG_MAX_DRAM_SIZE");
206  #endif
207   if (doe_max_dram_size_config) {
208    doe_max_dram_size = (u64)atoi(doe_max_dram_size_config);
209    if (doe_max_dram_size < 1)
210     doe_max_dram_size = 1;
211    print("DOE CUSTOM_CONFIG_MAX_DRAM_SIZE: %llx\n", doe_max_dram_size);
212    if (((doe_max_dram_size << size_shift) >> size_shift) != doe_max_dram_size)
213     goto out; /* overflow, use default value */
214    max_dram_size = doe_max_dram_size << size_shift;
215   }
216  out:
217   print("CUSTOM_CONFIG_MAX_DRAM_SIZE: 0x%llx\n", max_dram_size);
218   return max_dram_size;
219  }

//bootarg.orig_dram_info是在vendor/mediatek/proprietary/bootable/bootloader/preloader
   /platform/mt6739/src/drivers/platform.c的platform_init函数中初始化的
#if !CFG_FPGA_PLATFORM
1490  /*In FPGA phase, dram related function should by pass*/
1491      bootarg.dram_rank_num = get_dram_rank_nr();
1492      get_dram_rank_size(bootarg.dram_rank_size);
1493      get_orig_dram_rank_info(&bootarg.orig_dram_info);
1494      setup_mblock_info(&bootarg.mblock_info, &bootarg.orig_dram_info, &bootarg.lca_reserved_mem);
1495  #else


//vendor/mediatek/proprietary/bootable/bootloader/preloader/platform/mt6739/src/drivers/emi.c
3223  void get_orig_dram_rank_info(dram_info_t *orig_dram_info)
3224  {
3225   int i, j;
3226   u64 base = DRAM_BASE;
3227   u64 rank_size[4] = {0};
3228  
3229   i = get_dram_rank_nr();
3230   orig_dram_info->rank_num = (i > 0)? i : 0;
3231   get_dram_rank_size(rank_size);
3232   orig_dram_info->rank_info[0].start = base;
3233   for (i = 0; i < orig_dram_info->rank_num; i++) {
3234  
3235    orig_dram_info->rank_info[i].size = (u64)rank_size[i];
3236  
3237    if (i > 0) {
3238     orig_dram_info->rank_info[i].start =
3239      orig_dram_info->rank_info[i - 1].start +
3240      orig_dram_info->rank_info[i - 1].size;
3241    }
3242    printf("orig_dram_info[%d] start: 0x%llx, size: 0x%llx\n",
3243      i, orig_dram_info->rank_info[i].start,
3244      orig_dram_info->rank_info[i].size);
3245   }
3246  
3247   for(j=i; j<4; j++)
3248   {
3249       orig_dram_info->rank_info[j].start = 0;
3250       orig_dram_info->rank_info[j].size = 0;
3251   }
3252  }

43  //========================
44  #define DRAM_BASE 0x40000000ULL

3198  int get_dram_rank_nr (void)
3199  {
3200  
3201      int index;
3202      int emi_cona;
3203  //通过读取时序表，找到对应的DDR芯片时序
3204      index = mt_get_mdl_number ();
3205      if (index < 0 || index >=  num_of_emi_records)
3206      {
3207          return -1;
3208      }
3209  
3210      emi_cona = emi_settings[index].EMI_CONA_VAL;
3211  
3212  #if CFG_FPGA_PLATFORM
3213      return 1;
3214  #endif
3215  
3216      return (emi_cona & 0x20000) ? 2 : 1;
3217  
3218  }

//通过get_dram_rank_nr 函数获取rank 的数量，然后通过get_dram_rank_size 得到每个rank 的
size，所有rank 的大小加起来就是ddr 实际容量。

3257  void get_dram_rank_size (u64 dram_rank_size[])
3258  {
3259  
3260   int index,/* bits,*/ rank_nr, i;
3261      //int emi_cona;
3262  #if 1
3263      index = mt_get_mdl_number ();
3264  
3265      if (index < 0 || index >=  num_of_emi_records)
3266      {
3267          return;
3268      }
3269  
3270      rank_nr = get_dram_rank_nr();
3271  
3272      for(i = 0; i < rank_nr; i++){
3273          dram_rank_size[i] = emi_settings[index].DRAM_RANK_SIZE[i];
3274  
3275          printf("%d:dram_rank_size:%x\n",i,dram_rank_size[i]);
3276      }
3277  
3278      return;
3279  #endif
3280  }

//该变量在emigen中初始化，是通过perl脚本读取MemoryDeviceList.xls表格中的DENSITY项得到的
//vendor/mediatek/proprietary/bootable/bootloader/preloader/tools/emigen/MT6739/emigen.pl

862 EMI_SETTINGS emi_settings[] =
863 {
864      $EMI_SETTINGS_string
865 };

# LPDDR3
1060  elsif ($DDR1_2_3[$id] eq "LPDDR3")
1061         {
1062             $LPDDR3_MODE_REG1[$id]             = &xls_cell_value($Sheet, $_, $platform_scan_idx++) ;
1063             $LPDDR3_MODE_REG2[$id]             = &xls_cell_value($Sheet, $_, $platform_scan_idx++) ;
1064             $LPDDR3_MODE_REG3[$id]             = &xls_cell_value($Sheet, $_, $platform_scan_idx++) ;
1065             $LPDDR3_MODE_REG5[$id]             = &xls_cell_value($Sheet, $_, $platform_scan_idx++) ;
1066             $LPDDR3_MODE_REG10[$id]            = &xls_cell_value($Sheet, $_, $platform_scan_idx++) ;
1067             $LPDDR3_MODE_REG63[$id]            = &xls_cell_value($Sheet, $_, $platform_scan_idx++) ;
1068         }
1069 
1070         if ($DENSITY[$id] eq "8192+8192")
1071         {
1072             $DRAM_RANK0_SIZE[$id] = "0x40000000";
1073             $DRAM_RANK1_SIZE[$id] = "0x40000000";
1074         }
1075         elsif ($DENSITY[$id] eq "16384+8192")
1076         {
1077             $DRAM_RANK0_SIZE[$id] = "0x80000000";
1078             $DRAM_RANK1_SIZE[$id] = "0x40000000";
1079         }
1080         elsif ($DENSITY[$id] eq "8192+4096")
1081         {
1082             $DRAM_RANK0_SIZE[$id] = "0x40000000";
1083             $DRAM_RANK1_SIZE[$id] = "0x20000000";
1084         }
1085         elsif ($DENSITY[$id] eq "4096+4096")
1086         {
1087             $DRAM_RANK0_SIZE[$id] = "0x20000000";
1088             $DRAM_RANK1_SIZE[$id] = "0x20000000";
1089         }
1090         elsif ($DENSITY[$id] eq "2048+2048")
1091         {
1092             $DRAM_RANK0_SIZE[$id] = "0x10000000";
1093             $DRAM_RANK1_SIZE[$id] = "0x10000000";
1094         }
...

```

ddr mblock 的进一步划分
preloader中mblock_alloc_range函数解析
mblock_alloc_range用于分配reserve mblock,分配后的reserve mblock存放在bootarg.mblock
_info.reserved中，此时有三种情况：
1、如果reserve mblock的起始地址等于当前mblock起始地址,或者reserve mblock结束地址等于
当前mblock结束地址，则只需要修改当前mblock的start addr和size
2、如果reserve mblock 是在当前mblock之间，此时会把当前mblock拆分为2部分，需要增加一个mblock。

MT6739平台在preloader阶段分配了以下reserve mblock
Line  453: mblock_alloc_range: start: 0x00000000BFFFF000, sz: 0x0000000000001000 lower_bound: 0x0000000000000000 limit: 0x00000000C0000000 map:0 name:emi-reserved align: 0x0000000000001000
 Line  499: mblock_alloc_range: start: 0x0000000044600000, sz: 0x0000000000040000 lower_bound: 0x0000000000000000 limit: 0x0000000044640000 map:0 name:atf-reserved align: 0x0000000000010000
 Line  500: mblock_alloc_range: start: 0x00000000BFE00000, sz: 0x0000000000040000 lower_bound: 0x0000000000000000 limit: 0x00000000C0000000 map:0 name:atf-log-reserved align: 0x0000000000200000
 Line  524: mblock_alloc_range: start: 0x0000000070000000, sz: 0x0000000001C00000 lower_bound: 0x0000000000000000 limit: 0x0000000080000000 map:0 name:teei-reserved align: 0x0000000010000000
 Line  525: mblock_alloc_range: start: 0x00000000BFC00000, sz: 0x0000000000020000 lower_bound: 0x0000000000000000 limit: 0x00000000C0000000 map:0 name:tee-log-reserved align: 0x0000000000200000
 Line  526: mblock_alloc_range: start: 0x000000007FC00000, sz: 0x0000000000200000 lower_bound: 0x0000000000000000 limit: 0x0000000080000000 map:0 name:tee_ree_reserved align: 0x0000000000200000
 Line  530: mblock_alloc_range: start: 0x0000000044400000, sz: 0x0000000000010000 lower_bound: 0x0000000000000000 limit: 0x0000000044410000 map:0 name:aee_debug_kinfo align: 0x0000000000010000
 Line  531: mblock_alloc_range: start: 0x0000000044410000, sz: 0x00000000000E0000 lower_bound: 0x0000000000000000 limit: 0x00000000444F0000 map:0 name:pstore align: 0x0000000000010000
 Line  532: mblock_alloc_range: start: 0x00000000444F0000, sz: 0x0000000000010000 lower_bound: 0x0000000000000000 limit: 0x0000000044500000 map:0 name:minirdump align: 0x0000000000010000

lk中对mblock的划分
//vendor/mediatek/proprietary/bootable/bootloader/lk/lib/mblock/mblock_v2.c
lk中也是通过mblock模块实现mblock的分配，preloader通过bootarg将已经分配的reserve mblock
传给lk,lk中会额外再分配更多的reserve mblock，普通的mblock就是reserve mblock未使用的区域，
mblock的addr和size会通过bootarg传递给kernel。

ddr 时序的选择以及最终初始化流程
//vendor/mediatek/proprietary/bootable/bootloader/preloader/platform/mt6739/src/drivers/emi.c
通过mt_get_mdl_number函数获取匹配的DDR时序
如果配置了 mcp_dram，则通过emmc或nand匹配时序，否则如果配置了discrete_dram_num，则通过 
DDR的MR5匹配时序。
对于通过DDR匹配的情况，该函数中先调用mt_get_dram_type_for_dis函数通过 GPIO判断DDR类型，
然后调用对应的DDR初始化函数进行初始化，并通过DRAM_MRR函数读取MR5，然后通过和表格的MR5对比得到index。

## MT8786/MT6768机制

MT6768的mblock也是使用mblock_v2模块，和MT6739是一样的。

差异在于匹配时序时，会对比MR5和rank size，只有都相同才匹配成功。

### rank size的获取

rank size是通过读取MR8的值计算出来的。

从代码上可以看到，MT6739通过时序表的rank size计算总容量，而MT6768通过MR8的值计算总容量。

在旧的平台上，时序的选择只会匹配vendor ID,但是在新平台上，还会对比时序表中
的DDR容量和block相加计算到的容量匹配MR8计算到的值才会选择该时序。

### 代码中可以限制DDR可用容量

CUSTOM_CONFIG_MAX_DRAM_SIZE 这个宏在部分芯片平台有定义，用于限制preloader的mblock模块初始化时最大内存容量。
