package com.example.pdf.converter.service.persistence;

import com.example.pdf.converter.entity.Outbox;
import com.example.pdf.converter.entity.enums.SagaStatus;
import com.example.pdf.converter.event.FileConvertedEvent;
import com.example.pdf.converter.repository.OutboxRepository;
import com.example.pdf.converter.util.exceptions.PermanentProcessingException;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.json.JsonMapper;

import java.time.OffsetDateTime;
import java.util.UUID;

@Service
@RequiredArgsConstructor
public class OutboxService {

    private final OutboxRepository outboxRepository;
    private final JsonMapper jsonMapper;

    @Transactional
    public void saveSuccessEvent(UUID eventId, String pathToNewPdfFile) {

        FileConvertedEvent event = new FileConvertedEvent(
                eventId,
                SagaStatus.SUCCESS.name(),
                pathToNewPdfFile,
                null,
                null
        );

        save(eventId, event, SagaStatus.SUCCESS.name());
    }

    @Transactional
    public void saveFailureEvent(UUID eventId, PermanentProcessingException exception) {
        FileConvertedEvent event = new FileConvertedEvent(
                eventId,
                SagaStatus.FAILURE.name(),
                null,
                exception.getErrorCode().name(),
                exception.getPublicMessage());

        save(eventId, event, SagaStatus.FAILURE.name());
    }

    private void save(UUID eventId, FileConvertedEvent event, String eventType) {
        Outbox outbox = new Outbox();

        outbox.setId(UUID.randomUUID());
        outbox.setAggregateType("file-converted");
        outbox.setAggregateId(eventId.toString());
        outbox.setEventType(eventType);
        outbox.setPayload(jsonMapper.writeValueAsString(event));
        outbox.setCreatedAt(OffsetDateTime.now());

        outboxRepository.save(outbox);

    }

}
