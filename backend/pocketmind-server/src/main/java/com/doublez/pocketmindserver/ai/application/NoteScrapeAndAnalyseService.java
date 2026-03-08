package com.doublez.pocketmindserver.ai.application;

import com.doublez.pocketmindserver.mq.event.CrawlerRequestEvent;
import com.doublez.pocketmindserver.note.domain.note.NoteEntity;
import com.doublez.pocketmindserver.note.domain.note.NoteRepository;
import com.doublez.pocketmindserver.resource.application.NoteResourceSyncService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

@Slf4j
@Service
public class NoteScrapeAndAnalyseService {

    private final NoteRepository noteRepository;
    private final JinaReaderClient jinaReaderClient;
    private final AiAnalysePollingService analysePollingService;
    private final NoteResourceSyncService noteResourceSyncService;

    public NoteScrapeAndAnalyseService(NoteRepository noteRepository,
                                      JinaReaderClient jinaReaderClient,
                                      AiAnalysePollingService analysePollingService,
                                      NoteResourceSyncService noteResourceSyncService) {
        this.noteRepository = noteRepository;
        this.jinaReaderClient = jinaReaderClient;
        this.analysePollingService = analysePollingService;
        this.noteResourceSyncService = noteResourceSyncService;
    }

    public void handle(CrawlerRequestEvent event) {
        long userId = parseUserId(event.userId());
        var noteOpt = noteRepository.findByUuidAndUserId(event.uuid(), userId);
        if (noteOpt.isEmpty()) {
            return;
        }

        NoteEntity note = noteOpt.get();
        try {
            note.startFetching();
            noteRepository.update(note);

            var response = jinaReaderClient.fetchContent(event.url());
            if (response.code() == 200 && response.data() != null) {
                note.completeFetch(response.data().title(), response.data().description(), response.data().content());
            } else {
                note.failFetch();
            }
        } catch (Exception e) {
            log.warn("note scrape failed: uuid={}, url={}", event.uuid(), event.url(), e);
            note.failFetch();
        } finally {
            noteRepository.update(note);
            noteResourceSyncService.syncProjectedResources(note);
        }

        // 抓取完成后触发 AI 处理
        analysePollingService.process(event.userId(), event.uuid(), event.userQuestion());
    }

    private long parseUserId(String userId) {
        try {
            return Long.parseLong(userId);
        } catch (NumberFormatException e) {
            return -1L;
        }
    }
}
