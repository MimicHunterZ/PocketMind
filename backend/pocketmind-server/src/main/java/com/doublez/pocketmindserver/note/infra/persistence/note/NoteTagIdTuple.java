package com.doublez.pocketmindserver.note.infra.persistence.note;

import lombok.Data;
import java.util.UUID;

@Data
public class NoteTagIdTuple {
    private UUID noteUuid;
    private long tagId;
}
