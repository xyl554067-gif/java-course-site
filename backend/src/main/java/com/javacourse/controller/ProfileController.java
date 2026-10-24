package com.javacourse.controller;

import com.javacourse.model.ApiResponse;
import com.javacourse.repository.ProgressRepository;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/profile")
public class ProfileController {
    private final JdbcTemplate jdbc;
    private final ProgressRepository progress;
    public ProfileController(JdbcTemplate jdbc, ProgressRepository progress) { this.jdbc=jdbc;this.progress=progress; }
    private long uid(HttpServletRequest req) { return (Long) req.getAttribute("userId"); }

    @GetMapping
    public ApiResponse<Map<String,Object>> get(HttpServletRequest req) {
        long id=uid(req);
        return ApiResponse.ok(jdbc.queryForMap("SELECT username,nickname,email,avatar,created_at FROM app_user WHERE id=?",id));
    }
    @PutMapping
    public ApiResponse<Map<String,Object>> update(HttpServletRequest req,@RequestBody Map<String,String> body) {
        String nickname=clean(body.get("nickname"),64), avatar=clean(body.get("avatar"),255), email=clean(body.get("email"),128);
        if(nickname==null||nickname.isBlank()) return ApiResponse.error(400,"昵称不能为空");
        jdbc.update("UPDATE app_user SET nickname=?,avatar=?,email=?,updated_at=CURRENT_TIMESTAMP WHERE id=?",nickname,blankToNull(avatar),blankToNull(email),uid(req));
        return get(req);
    }
    @GetMapping("/calendar")
    public ApiResponse<List<Map<String,Object>>> calendar(HttpServletRequest req,@RequestParam int year,@RequestParam int month) {
        if(month<1||month>12||year<2000||year>2200) return ApiResponse.error(400,"年月范围无效");
        return ApiResponse.ok(progress.calendar(uid(req),year,month));
    }
    @GetMapping("/achievements")
    public ApiResponse<List<Map<String,Object>>> achievements(HttpServletRequest req) {
        long id=uid(req);
        long seconds=jdbc.queryForObject("SELECT COALESCE(SUM(total_seconds),0) FROM learning_activity WHERE user_id=?",Long.class,id);
        int lessons=jdbc.queryForObject("SELECT COUNT(*) FROM learning_progress WHERE user_id=? AND completed=1",Integer.class,id);
        int days=jdbc.queryForObject("SELECT COUNT(DISTINCT activity_date) FROM learning_activity WHERE user_id=? AND (total_seconds>0 OR completed=1)",Integer.class,id);
        return ApiResponse.ok(List.of(
                achievement("first-lesson","启程","完成第一课时",lessons>=1),
                achievement("five-lessons","稳步前进","完成 5 个课时",lessons>=5),
                achievement("one-hour","专注学习","累计真实学习 1 小时",seconds>=3600),
                achievement("three-days","持续学习","在 3 个不同日期有学习记录",days>=3)));
    }
    private Map<String,Object> achievement(String id,String title,String description,boolean unlocked) {
        Map<String,Object> m=new HashMap<>();m.put("id",id);m.put("title",title);m.put("description",description);m.put("unlocked",unlocked);return m;
    }
    private String clean(String value,int max){if(value==null)return "";String s=value.trim();return s.length()>max?s.substring(0,max):s;}
    private String blankToNull(String s){return s==null||s.isBlank()?null:s;}
}
