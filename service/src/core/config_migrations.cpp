#include "config_migrations.h"

namespace beenut {
namespace {

constexpr int kCurrentConfigSchemaVersion = 1;

int schemaVersion(const QJsonObject& root)
{
    const auto value = root.value("schema_version");
    return value.isDouble() ? value.toInt() : 0;
}

}  // namespace

int currentConfigSchemaVersion()
{
    return kCurrentConfigSchemaVersion;
}

ConfigMigrationResult migrateConfig(QJsonObject root)
{
    ConfigMigrationResult result;
    const int declaredVersion = schemaVersion(root);
    result.fromVersion = declaredVersion == 0 ? 1 : declaredVersion;
    result.toVersion = result.fromVersion;

    if (declaredVersion == 0) {
        root.insert("schema_version", kCurrentConfigSchemaVersion);
        result.toVersion = kCurrentConfigSchemaVersion;
        result.migrated = true;
        result.changes.append("Added schema_version=1");
    }

    // Future migrations should be added here as deterministic transforms:
    // while (result.toVersion < kCurrentConfigSchemaVersion) { ... }

    result.config = root;
    return result;
}

}  // namespace beenut
