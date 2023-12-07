#SD卡格式化为便携式或内部存储的流程

格式化和插入拔出流程：
搜索关键字  StorageNotification ，会打印SD卡 格式化流程，其中便携式格式化会显示为：
state=EJECTING -》 state=UNMOUNTED -》 state=BAD_REMOVAL -》state=UNMOUNTED -》state=CHECKING -》state=UNMOUNTED -》 state=CHECKING -》state=MOUNTED的过程， 格式化完成后：
StorageNotification: Notifying about public volume: VolumeInfo{public:179,97}:
StorageNotification:     type=PUBLIC diskId=disk:179,96 partGuid= mountFlags=VISIBLE_FOR_WRITE 
StorageNotification:     mountUserId=0 state=MOUNTED 
StorageNotification:     fsType=vfat fsUuid=87FF-0DE9 fsLabel= 
StorageNotification:     path=/storage/87FF-0DE9 internalPath=/mnt/media_rw/87FF-0DE9 
StorageWizardReady: onVolumeStateChanged, disk : disk:179,96, type : 0, state : 2

格式化为内部存储：
state=EJECTING -》state=UNMOUNTED -》state=BAD_REMOVAL -》state=UNMOUNTED -》state=REMOVED -》state=UNMOUNTED -》state=CHECKING -》state=MOUNTED 
格式完成后：
StorageNotification: Notifying about private volume: VolumeInfo{private:179,98}:
StorageNotification:     type=PRIVATE diskId=disk:179,96 
StorageNotification:     partGuid=B508F866-2158-4B34-A5CA-ACF160957EBB mountFlags=0 mountUserId=-1 
StorageNotification:     state=MOUNTED 
StorageNotification:     fsType=ext4 fsUuid=c7059403-add4-4f4a-81ea-291a9d1ef957 fsLabel= 
StorageNotification:     path=/mnt/expand/c7059403-add4-4f4a-81ea-291a9d1ef957 internalPath=null 



拔出SD卡：
state=EJECTING -》 state=UNMOUNTED -》 state=BAD_REMOVAL 

重新插入SD卡：
state=UNMOUNTED -》state=CHECKING -》 state=MOUNTED

格式化为内部或便携式区分可查MediaStore 关键字

SD格式化为便携式时，此时EMMC就是 内部存储，会显示
Emmc: MediaStore: Examining volume emulated;0 with name external_primary and state mounted
SD: MediaStore: Examining volume public:179,97 with name 87ff-0de9 and state mounted

SD格式化为内部存储，但没有迁移数据：
MediaStore: Examining volume emulated;0 with name external_primary and state mounted
MediaStore: Examining volume public:179,97 with name 87ff-0de9 and state ejecting

数据迁移到SD后：
MediaStore: Examining volume emulated;0 with name external_primary and state ejecting
MediaStore: Examining volume emulated:179,98;0 with name external_primary and state mounted

此时拔出SD，进设置-存储会闪退，因为缺少external_primary：
MediaStore: Examining volume emulated:179,98;0 with name external_primary and state ejecting

再将SD格式化为便携式
MediaStore: Examining volume emulated:179,98;0 with name external_primary and state ejecting
Examining volume stub_primary with name external_primary and state removed
Examining volume public:179,97 with name 2a30-0df0 and state mounted
Examining volume emulated;0 with name external_primary and state mounted
