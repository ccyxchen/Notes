# block IO工具研发

## perffeto ui运行

## block trace 研究
trace event 说明

block trace：
100135925:/ # ls /sys/kernel/tracing/instances/block/events/block/
block_bio_backmerge  block_bio_frontmerge  block_dirty_buffer  block_rq_complete  block_rq_remap    block_split         enable
block_bio_bounce     block_bio_queue       block_getrq         block_rq_insert    block_rq_requeue  block_touch_buffer  filter
block_bio_complete   block_bio_remap       block_plug          block_rq_issue     block_sleeprq     block_unplug

emmc trace:
100135925:/ # ls /sys/kernel/tracing/instances/block/events/mmc/
enable  filter  mmc_request_done  mmc_request_start

scsi trace:
100135925:/ # ls /sys/kernel/tracing/instances/block/events/scsi/
enable  filter  scsi_dispatch_cmd_done  scsi_dispatch_cmd_error  scsi_dispatch_cmd_start  scsi_dispatch_cmd_timeout  scsi_eh_wakeup

lamu:/ # ls /sys/kernel/tracing/instances/block/events/ufs
enable                   ufshcd_clk_scaling      ufshcd_profile_clk_gating   ufshcd_runtime_suspend  ufshcd_upiu                ufshcd_wl_suspend
filter                   ufshcd_command          ufshcd_profile_clk_scaling  ufshcd_system_resume    ufshcd_wl_resume
ufshcd_auto_bkops_state  ufshcd_exception_event  ufshcd_profile_hibern8      ufshcd_system_suspend   ufshcd_wl_runtime_resume
ufshcd_clk_gating        ufshcd_init             ufshcd_runtime_resume       ufshcd_uic_command      ufshcd_wl_runtime_suspend

文件系统 trace：
lamu:/ # ls /sys/kernel/tracing/instances/block/events/f2fs/
enable                       f2fs_gc_begin                     f2fs_readdir                     f2fs_truncate_blocks_enter
f2fs_background_gc           f2fs_gc_end                       f2fs_readpage                    f2fs_truncate_blocks_exit
f2fs_bmap                    f2fs_get_victim                   f2fs_readpages                   f2fs_truncate_data_blocks_range
f2fs_compress_pages_end      f2fs_iget                         f2fs_remove_discard              f2fs_truncate_inode_blocks_enter
f2fs_compress_pages_start    f2fs_iget_exit                    f2fs_rename_end                  f2fs_truncate_inode_blocks_exit
f2fs_dataread_end            f2fs_iostat                       f2fs_rename_start                f2fs_truncate_node
f2fs_dataread_start          f2fs_iostat_latency               f2fs_replace_atomic_write_block  f2fs_truncate_nodes_enter
f2fs_datawrite_end           f2fs_issue_discard                f2fs_reserve_new_blocks          f2fs_truncate_nodes_exit
f2fs_datawrite_start         f2fs_issue_flush                  f2fs_set_page_dirty              f2fs_truncate_partial_nodes
f2fs_decompress_pages_end    f2fs_issue_reset_zone             f2fs_shrink_extent_tree          f2fs_unlink_enter
f2fs_decompress_pages_start  f2fs_lookup_age_extent_tree_end   f2fs_shutdown                    f2fs_unlink_exit
f2fs_destroy_extent_tree     f2fs_lookup_end                   f2fs_submit_page_bio             f2fs_update_age_extent_tree_range
f2fs_direct_IO_enter         f2fs_lookup_extent_tree_start     f2fs_submit_page_write           f2fs_update_read_extent_tree_range
f2fs_direct_IO_exit          f2fs_lookup_read_extent_tree_end  f2fs_submit_read_bio             f2fs_vm_page_mkwrite
f2fs_do_write_data_page      f2fs_lookup_start                 f2fs_submit_write_bio            f2fs_write_begin
f2fs_drop_inode              f2fs_map_blocks                   f2fs_sync_dirty_inodes_enter     f2fs_write_checkpoint
f2fs_evict_inode             f2fs_new_inode                    f2fs_sync_dirty_inodes_exit      f2fs_write_end
f2fs_fallocate               f2fs_prepare_read_bio             f2fs_sync_file_enter             f2fs_writepage
f2fs_fiemap                  f2fs_prepare_write_bio            f2fs_sync_file_exit              f2fs_writepages
f2fs_file_write_iter         f2fs_queue_discard                f2fs_sync_fs                     filter
f2fs_filemap_fault           f2fs_queue_reset_zone             f2fs_truncate

内存 trace：
lamu:/ # ls /sys/kernel/tracing/instances/block/events/filemap/
enable  file_check_and_advance_wb_err  filemap_set_wb_err  filter  mm_filemap_add_to_page_cache  mm_filemap_delete_from_page_cache

lamu:/ # ls /sys/kernel/tracing/instances/block/events/kmem/
enable  kfree    kmem_cache_alloc  mm_page_alloc          mm_page_alloc_zone_locked  mm_page_free_batched  rss_stat
filter  kmalloc  kmem_cache_free   mm_page_alloc_extfrag  mm_page_free               mm_page_pcpu_drain

## trace具体解析

block_rq_issue -> block 下发到块设备起点

blk_mq_sched_dispatch_requests
blk_mq_start_request->blk_mq_dispatch_rq_list->
