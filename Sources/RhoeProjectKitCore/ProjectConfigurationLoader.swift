import Foundation
import RhoeMarkdownModel
import RhoeMarkdownKit
import RhoeMarkdownParsing

/// Loads and decodes `rhoe.project.yaml` into typed `ProjectConfiguration`.
public struct ProjectConfigurationLoader: Sendable {

    public init() {}

    /// Load configuration from a YAML file URL.
    public func load(from url: URL) throws -> ProjectConfiguration {
        let yamlString = try String(contentsOf: url, encoding: .utf8)
        return try load(from: yamlString)
    }

    /// Load configuration from a YAML string.
    public func load(from yamlString: String) throws -> ProjectConfiguration {
        // Parse YAML using the existing frontmatter parser
        let yaml = parseYAML(yamlString)
        return decode(yaml)
    }

    // MARK: - YAML Parsing

    private func parseYAML(_ yaml: String) -> [String: RhoeMarkdownKit.YAMLValue] {
        // Strip frontmatter delimiters if present
        var content = yaml
        if content.hasPrefix("---\n") {
            content = String(content.dropFirst(4))
            if let endRange = content.range(of: "\n---") {
                content = String(content[content.startIndex..<endRange.lowerBound])
            }
        }

        // Use the full recursive YAML parser from RhoeMarkdownParsing
        return RhoeParser().parseYAMLContent(content)
    }

    // MARK: - Decoding

    private func decode(_ yaml: [String: RhoeMarkdownKit.YAMLValue]) -> ProjectConfiguration {
        let version = yaml["rhoe_project"]?.intValue ?? yaml["version"]?.intValue ?? 1

        return ProjectConfiguration(
            schemaVersion: version,
            project: decodeProjectMetadata(yaml["project"]),
            paths: decodePathConfig(yaml["paths"]),
            site: decodeSiteConfig(yaml["site"]),
            collections: decodeCollections(yaml["collections"]),
            defaults: decodeDefaults(yaml["defaults"]),
            navigation: decodeNavigation(yaml["navigation"]),
            targets: decodeTargets(yaml["targets"]),
            profiles: decodeProfiles(yaml["profiles"])
        )
    }

    private func decodeProjectMetadata(_ value: RhoeMarkdownKit.YAMLValue?) -> ProjectMetadata {
        guard let map = value?.dictionaryValue else { return .init() }
        return ProjectMetadata(
            id: map["id"]?.stringValue ?? "untitled",
            name: map["name"]?.stringValue ?? "Untitled Project",
            title: map["title"]?.stringValue,
            description: map["description"]?.stringValue,
            language: map["language"]?.stringValue ?? "en",
            timezone: map["timezone"]?.stringValue,
            version: map["version"]?.stringValue
        )
    }

    private func decodePathConfig(_ value: RhoeMarkdownKit.YAMLValue?) -> PathConfiguration {
        guard let map = value?.dictionaryValue else { return .init() }
        return PathConfiguration(
            source: map["source"]?.stringValue ?? ".",
            data: map["data"]?.stringValue ?? "_data",
            layouts: map["layouts"]?.stringValue ?? "_layouts",
            includes: map["includes"]?.stringValue ?? "_includes",
            assets: map["assets"]?.stringValue ?? "assets",
            output: map["output"]?.stringValue ?? "_site",
            build: map["build"]?.stringValue ?? ".build",
            cache: map["cache"]?.stringValue ?? ".cache"
        )
    }

    private func decodeSiteConfig(_ value: RhoeMarkdownKit.YAMLValue?) -> SiteConfiguration {
        guard let map = value?.dictionaryValue else { return .init() }
        let author: AuthorInfo? = map["author"].flatMap { val in
            if let name = val.stringValue { return AuthorInfo(name: name) }
            if let authorMap = val.dictionaryValue {
                return AuthorInfo(
                    name: authorMap["name"]?.stringValue ?? "",
                    url: authorMap["url"]?.stringValue,
                    email: authorMap["email"]?.stringValue
                )
            }
            return nil
        }
        return SiteConfiguration(
            url: map["url"]?.stringValue,
            title: map["title"]?.stringValue,
            subtitle: map["subtitle"]?.stringValue,
            author: author,
            logo: map["logo"]?.stringValue,
            favicon: map["favicon"]?.stringValue,
            locale: map["locale"]?.stringValue
        )
    }

    private func decodeCollections(_ value: RhoeMarkdownKit.YAMLValue?) -> [String: CollectionDefinition] {
        guard let map = value?.dictionaryValue else { return [:] }
        var result: [String: CollectionDefinition] = [:]
        for (name, colVal) in map {
            guard let colMap = colVal.dictionaryValue else { continue }
            let targetRoles: [String] = colMap["target_roles"]?.arrayValue?.compactMap(\.stringValue) ?? []
            result[name] = CollectionDefinition(
                path: colMap["path"]?.stringValue ?? "_\(name)",
                output: colMap["output"]?.boolValue ?? true,
                permalink: colMap["permalink"]?.stringValue,
                sortBy: colMap["sort_by"]?.stringValue,
                reverse: colMap["reverse"]?.boolValue ?? false,
                defaults: colMap["defaults"]?.dictionaryValue ?? [:],
                targetRoles: targetRoles
            )
        }
        return result
    }

    private func decodeDefaults(_ value: RhoeMarkdownKit.YAMLValue?) -> [DefaultScope] {
        guard let arr = value?.arrayValue else { return [] }
        return arr.compactMap { item -> DefaultScope? in
            guard let map = item.dictionaryValue,
                  let scopeVal = map["scope"]?.dictionaryValue,
                  let values = map["values"]?.dictionaryValue else { return nil }
            let scope = ScopePattern(
                path: scopeVal["path"]?.stringValue,
                type: scopeVal["type"]?.stringValue
            )
            return DefaultScope(scope: scope, values: values)
        }
    }

    private func decodeNavigation(_ value: RhoeMarkdownKit.YAMLValue?) -> NavigationConfiguration {
        guard let map = value?.dictionaryValue else { return .init() }
        let mode = NavigationMode(rawValue: map["mode"]?.stringValue ?? "auto") ?? .auto
        let sidebar: SidebarConfiguration? = map["sidebar"]?.dictionaryValue.map { sidebarMap in
            SidebarConfiguration(
                style: sidebarMap["style"]?.stringValue ?? "tree",
                collapsible: sidebarMap["collapsible"]?.boolValue ?? true,
                maxDepth: sidebarMap["max_depth"]?.intValue ?? 3
            )
        }
        return NavigationConfiguration(mode: mode, sidebar: sidebar)
    }

    private func decodeTargets(_ value: RhoeMarkdownKit.YAMLValue?) -> [String: TargetDefinition] {
        guard let map = value?.dictionaryValue else { return [:] }
        var result: [String: TargetDefinition] = [:]
        for (name, targetVal) in map {
            guard let targetMap = targetVal.dictionaryValue else { continue }
            let type = TargetType(rawValue: targetMap["type"]?.stringValue ?? "static_site") ?? .staticSite
            let collections = targetMap["collections"]?.arrayValue?.compactMap(\.stringValue) ?? []
            result[name] = TargetDefinition(
                type: type,
                enabled: targetMap["enabled"]?.boolValue ?? true,
                outputDir: targetMap["output_dir"]?.stringValue,
                collections: collections,
                outputFormat: targetMap["output_format"]?.stringValue,
                visibility: targetMap["visibility"]?.stringValue
            )
        }
        return result
    }

    private func decodeProfiles(_ value: RhoeMarkdownKit.YAMLValue?) -> [String: BuildProfile] {
        guard let map = value?.dictionaryValue else { return [:] }
        var result: [String: BuildProfile] = [:]
        for (name, profileVal) in map {
            guard let profileMap = profileVal.dictionaryValue else { continue }
            let validation: ValidationPolicy? = profileMap["validation"]?.dictionaryValue.map { vMap in
                ValidationPolicy(
                    strict: vMap["strict"]?.boolValue ?? false,
                    brokenLinks: DiagnosticLevel(rawValue: vMap["broken_links"]?.stringValue ?? "warn") ?? .warn
                )
            }
            let execution: ExecutionPolicy? = profileMap["execution"]?.dictionaryValue.map { eMap in
                ExecutionPolicy(
                    codeCells: CodeCellPolicy(rawValue: eMap["code_cells"]?.stringValue ?? "skip") ?? .skip
                )
            }
            result[name] = BuildProfile(validation: validation, execution: execution)
        }
        return result
    }
}

// MARK: - YAMLValue Convenience Extensions

private extension RhoeMarkdownKit.YAMLValue {
    var intValue: Int? {
        if case .int(let v) = self { return v }
        if case .string(let s) = self { return Int(s) }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        if case .string(let s) = self { return s == "true" }
        return nil
    }

    var stringValue: String? {
        if case .string(let v) = self { return v }
        if case .int(let v) = self { return String(v) }
        return nil
    }

    var dictionaryValue: [String: RhoeMarkdownKit.YAMLValue]? {
        if case .dictionary(let v) = self { return v }
        return nil
    }

    var arrayValue: [RhoeMarkdownKit.YAMLValue]? {
        if case .array(let v) = self { return v }
        return nil
    }
}
