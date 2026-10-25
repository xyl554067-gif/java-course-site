package com.javacourse.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.core.io.ClassPathResource;
import org.springframework.jdbc.datasource.init.EncodedResource;
import org.springframework.jdbc.datasource.init.ScriptUtils;
import org.springframework.stereotype.Component;

import javax.sql.DataSource;
import java.sql.Connection;

/** Initializes a brand-new hosted PostgreSQL database before the feature-schema runners execute. */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE)
public class PostgresDatabaseBootstrap implements ApplicationRunner {
    private static final Logger log = LoggerFactory.getLogger(PostgresDatabaseBootstrap.class);

    private final DataSource dataSource;

    public PostgresDatabaseBootstrap(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    @Override
    public void run(ApplicationArguments args) throws Exception {
        try (Connection connection = dataSource.getConnection()) {
            String product = connection.getMetaData().getDatabaseProductName();
            if (product == null || !product.toLowerCase().contains("postgresql")) {
                return;
            }

            if (tableExists(connection, "app_user")) {
                return;
            }

            log.info("Empty PostgreSQL database detected; applying base schema and course seed data");
            boolean originalAutoCommit = connection.getAutoCommit();
            connection.setAutoCommit(false);
            try {
                ScriptUtils.executeSqlScript(connection,
                        new EncodedResource(new ClassPathResource("db/schema-postgresql.sql")));
                ScriptUtils.executeSqlScript(connection,
                        new EncodedResource(new ClassPathResource("db/seed-postgresql.sql")));
                connection.commit();
                log.info("PostgreSQL base schema and course seed data initialized");
            } catch (Exception exception) {
                connection.rollback();
                throw exception;
            } finally {
                connection.setAutoCommit(originalAutoCommit);
            }
        }
    }

    private boolean tableExists(Connection connection, String tableName) throws Exception {
        try (var statement = connection.prepareStatement("SELECT to_regclass(?) IS NOT NULL")) {
            statement.setString(1, "public." + tableName);
            try (var result = statement.executeQuery()) {
                return result.next() && result.getBoolean(1);
            }
        }
    }
}