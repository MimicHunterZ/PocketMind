package com.doublez.pocketmindserver.attachment.domain.attachment;

/** 附件来源 */
public enum AttachmentSource {
    /** 用户主动上传 */
    USER,
    /** 爬虫从帖子内抓取 */
    SCRAPE
}
