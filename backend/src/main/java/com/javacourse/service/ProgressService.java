package com.javacourse.service;

import com.javacourse.repository.ProgressRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * 学习进度与收藏服务
 */
@Service
public class ProgressService {

    /** 全站课时总数，用于计算总进度百分比 */
    private static final long TOTAL_LESSONS = 42L;

    private final ProgressRepository repo;

    public ProgressService(ProgressRepository repo) {
        this.repo = repo;
    }

    /** 学习总览 */
    public Map<String, Object> summary(long userId) {
        Map<String, Object> s = repo.summary(userId, TOTAL_LESSONS);
        long completed = toLong(s.get("completed"));
        s.put("overallPct", TOTAL_LESSONS == 0 ? 0
                : (int) Math.round(completed * 100.0 / TOTAL_LESSONS));
        return s;
    }

    /** 全部进度记录 */
    public Map<String, Object> list(long userId) {
        Map<String, Object> out = new HashMap<>();
        out.put("summary", summary(userId));
        out.put("items", repo.listByUser(userId));
        out.put("favorites", repo.listFavorites(userId));
        return out;
    }

    /** 单课时进度 */
    public Map<String, Object> get(long userId, long lessonId) {
        Map<String, Object> p = repo.findOne(userId, lessonId);
        Map<String, Object> out = new HashMap<>();
        out.put("progress", p);
        out.put("favorite", repo.isFavorite(userId, lessonId));
        return out;
    }

    /** 保存进度（前端滚动/心跳时调用） */
    @Transactional
    public Map<String, Object> save(long userId, long lessonId,
                                    Integer progressPct, Integer lastSeconds) {
        int pct = progressPct == null ? 0 : progressPct;
        // 进度到 100% 自动视为完成，避免前端漏传 completed
        boolean completed = pct >= 100;
        repo.upsert(userId, lessonId, pct, completed, lastSeconds == null ? 0 : lastSeconds);
        return get(userId, lessonId);
    }

    /** 标记完成/取消 */
    @Transactional
    public Map<String, Object> mark(long userId, long lessonId, boolean completed) {
        repo.markCompleted(userId, lessonId, completed);
        return get(userId, lessonId);
    }

    /** 收藏，返回切换后的状态 */
    @Transactional
    public Map<String, Object> toggleFavorite(long userId, long lessonId) {
        boolean nowFavorite;
        if (repo.isFavorite(userId, lessonId)) {
            repo.removeFavorite(userId, lessonId);
            nowFavorite = false;
        } else {
            repo.addFavorite(userId, lessonId);
            nowFavorite = true;
        }
        Map<String, Object> out = new HashMap<>();
        out.put("favorite", nowFavorite);
        out.put("summary", summary(userId));
        return out;
    }

    /** 批量取收藏与完成状态，供课程目录打标 */
    public Map<String, Object> marks(long userId) {
        Map<String, Object> out = new HashMap<>();
        out.put("favorites", repo.favoriteIds(userId));
        out.put("completed", repo.completedIds(userId));
        return out;
    }

    /** JDBC 聚合返回值可能是 Long 也可能是 BigDecimal，统一取 long */
    private static long toLong(Object v) {
        return v instanceof Number ? ((Number) v).longValue() : 0L;
    }
}