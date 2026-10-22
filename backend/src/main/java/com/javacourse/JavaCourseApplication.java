package com.javacourse;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;
import org.springframework.scheduling.annotation.EnableAsync;

/**
 * Java 课程介绍网站 - 后端服务入口
 */
@SpringBootApplication
@ConfigurationPropertiesScan
@EnableAsync
public class JavaCourseApplication {

    public static void main(String[] args) {
        SpringApplication.run(JavaCourseApplication.class, args);
    }
}
