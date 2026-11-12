package com.javacourse.service;

import org.springframework.stereotype.Component;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.function.LongSupplier;

/** Bounded, per-account request limits. A single instance protects one application process. */
@Component
public class AssistantRequestLimit {
    private static final long WINDOW = TimeUnit.MINUTES.toNanos(1);
    private static final int MAX_ACCOUNTS = 4096;
    private final Map<Long, Usage> accounts = new HashMap<>();
    private final LongSupplier clock;
    private long lastSweep;

    public AssistantRequestLimit() {
        this(System::nanoTime);
    }

    AssistantRequestLimit(LongSupplier clock) {
        this.clock = clock;
        lastSweep = clock.getAsLong();
    }

    public synchronized int retryAfter(long userId, boolean connectionTest) {
        long now = clock.getAsLong();
        if (now - lastSweep >= WINDOW) {
            accounts.values().removeIf(usage -> now - usage.start >= WINDOW);
            lastSweep = now;
        }
        Usage usage = accounts.get(userId);
        if (usage == null && accounts.size() >= MAX_ACCOUNTS) return 60;
        if (usage == null || now - usage.start >= WINDOW) {
            usage = new Usage(now);
            accounts.put(userId, usage);
        }
        if (connectionTest ? usage.tests >= 5 : usage.questions >= 12) {
            return (int) Math.max(1, TimeUnit.NANOSECONDS.toSeconds(WINDOW - (now - usage.start) - 1) + 1);
        }
        if (connectionTest) usage.tests++;
        else usage.questions++;
        return 0;
    }

    private static final class Usage {
        private final long start;
        private int questions;
        private int tests;

        private Usage(long start) {
            this.start = start;
        }
    }
}
