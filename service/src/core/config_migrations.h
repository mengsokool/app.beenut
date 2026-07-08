#pragma once

#include <QJsonArray>
#include <QJsonObject>

namespace beenut {

struct ConfigMigrationResult {
    QJsonObject config;
    int fromVersion = 1;
    int toVersion = 1;
    bool migrated = false;
    QJsonArray changes;
};

int currentConfigSchemaVersion();
ConfigMigrationResult migrateConfig(QJsonObject root);

}  // namespace beenut
