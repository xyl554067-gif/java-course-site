package com.javacourse.config;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.support.EncodedResource;
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

            if (!tableExists(connection, "app_user")) {
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

            normalizeSeededCodeNewlines(connection);
        }
    }

    /** Repairs existing seed rows written with literal backslash-n by PostgreSQL standard strings. */
    private void normalizeSeededCodeNewlines(Connection connection) throws Exception {
        if (!tableExists(connection, "code_snippet")) {
            return;
        }

        String escapedNewline = "\\n";
        String newline = "\n";
        String sql = "UPDATE code_snippet SET code_text = REPLACE(code_text, ?, ?) "
                + "WHERE POSITION(? IN code_text) > 0 AND POSITION(? IN code_text) = 0";
        try (var statement = connection.prepareStatement(sql)) {
            statement.setString(1, escapedNewline);
            statement.setString(2, newline);
            statement.setString(3, escapedNewline);
            statement.setString(4, newline);
            int updated = statement.executeUpdate();
            if (updated > 0) {
                log.info("Normalized line endings in {} seeded code snippet(s)", updated);
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