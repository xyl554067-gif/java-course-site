package com.javacourse.controller;

import com.javacourse.model.ApiResponse;
import com.javacourse.service.SearchService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * 搜索接口
 */
@RestController
public class SearchController {

    private final SearchService searchService;

    public SearchController(SearchService searchService) {
        this.searchService = searchService;
    }

    @GetMapping("/search")
    public ApiResponse<List<Map<String, Object>>> search(@RequestParam("q") String q) {
        return ApiResponse.ok(searchService.search(q));
    }

    @GetMapping("/search/suggest")
    public ApiResponse<List<String>> suggest(@RequestParam("q") String q) {
        List<Map<String, Object>> hits = searchService.search(q);
        return ApiResponse.ok(hits.stream()
                .map(h -> String.valueOf(h.get("title")))
                .distinct()
                .limit(10)
                .toList());
    }
}
