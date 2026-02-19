package com.doublez.pocketmindserver.attachment.domain.attachment;

/** 附件存储位置类型 */
public enum StorageType {
    /** 客户端本地路径（pocket_images/xxx.jpg） */
    LOCAL,
    /** 后端服务器本地（uploads/{userId}/sha256.ext） */
    SERVER,
    /** 对象存储（OSS key） */
    OSS
}
