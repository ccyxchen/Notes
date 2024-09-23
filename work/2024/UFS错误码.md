# UFS 错误码

```C
kernel-5.10/drivers/scsi/ufs/ufs.h

enum {
    QUERY_RESULT_SUCCESS                    = 0x00,
    QUERY_RESULT_NOT_READABLE               = 0xF6,
    QUERY_RESULT_NOT_WRITEABLE              = 0xF7,
    QUERY_RESULT_ALREADY_WRITTEN            = 0xF8,
    QUERY_RESULT_INVALID_LENGTH             = 0xF9,
    QUERY_RESULT_INVALID_VALUE              = 0xFA,
    QUERY_RESULT_INVALID_SELECTOR           = 0xFB,
    QUERY_RESULT_INVALID_INDEX              = 0xFC,
    QUERY_RESULT_INVALID_IDN                = 0xFD,
    QUERY_RESULT_INVALID_OPCODE             = 0xFE,
    QUERY_RESULT_GENERAL_FAILURE            = 0xFF,
};
```
