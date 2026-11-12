package com.javacourse.service;

import org.junit.jupiter.api.Test;

import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

import static org.junit.jupiter.api.Assertions.assertEquals;

class AssistantRequestLimitTest {
    @Test
    void tracksEachAccountAndActionAndResetsAfterOneMinute() {
        AtomicLong time = new AtomicLong();
        AssistantRequestLimit limit = new AssistantRequestLimit(time::get);
        for (int i = 0; i < 12; i++) assertEquals(0, limit.retryAfter(1, false));
        assertEquals(60, limit.retryAfter(1, false));
        for (int i = 0; i < 5; i++) assertEquals(0, limit.retryAfter(1, true));
        assertEquals(60, limit.retryAfter(1, true));
        assertEquals(0, limit.retryAfter(2, false));
        time.set(TimeUnit.SECONDS.toNanos(59));
        assertEquals(1, limit.retryAfter(1, false));
        time.set(TimeUnit.MINUTES.toNanos(1));
        assertEquals(0, limit.retryAfter(1, false));
        assertEquals(0, limit.retryAfter(1, true));
    }
}
