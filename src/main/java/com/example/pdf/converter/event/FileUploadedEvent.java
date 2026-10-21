package com.example.pdf.converter.event;

import java.util.UUID;

public record FileUploadedEvent(
        UUID eventId,
        String pathToFile
) {
}
