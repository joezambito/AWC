import Foundation

@MainActor
extension WealthExternalDataStore {
    func refreshResearchInputs(
        for blueprints: [OpportunityBlueprint],
        modeLabel: String,
        refreshTime: Date
    ) async {
        let records = deduplicatedBlueprints(blueprints)
        guard !records.isEmpty else { return }

        var nextSnapshots = researchSnapshotsByKey
        var nextStates = sourceStatesByKind
        var nextDates = sourceUpdatedAtByKind
        var nextDetails = sourceDetailByKind
        var summaryParts: [String] = []

        for client in activeFeedClients() {
            let result = await refreshSource(
                client: client,
                blueprints: records,
                refreshTime: refreshTime,
                modeLabel: modeLabel,
                existingSnapshots: nextSnapshots
            )

            for snapshot in result.snapshots {
                nextSnapshots[snapshot.key] = snapshot
            }

            nextStates[client.kind] = result.state
            if let updatedAt = result.updatedAt {
                nextDates[client.kind] = updatedAt
            }
            nextDetails[client.kind] = result.detail
            summaryParts.append("\(client.kind.displayName): \(result.state.rawValue)")
        }

        applyResearchRefreshState(
            snapshots: nextSnapshots,
            states: nextStates,
            updatedAt: nextDates,
            details: nextDetails,
            refreshedAt: refreshTime
        )
        persistResearchState()

        WealthEventLogStore.shared.record(
            title: "Research Refresh",
            detail: "\(modeLabel) external research refresh finished. " + summaryParts.joined(separator: " · "),
            category: "research",
            tintName: summaryParts.contains(where: { $0.contains(WealthExternalSignalState.freshOnline.rawValue) }) ? "green" : "orange",
            timestamp: refreshTime
        )
    }

    private func deduplicatedBlueprints(_ blueprints: [OpportunityBlueprint]) -> [OpportunityBlueprint] {
        var seen: Set<String> = []
        return blueprints.filter { blueprint in
            seen.insert(researchKey(for: blueprint)).inserted
        }
    }

    private func refreshSource(
        client: any WealthExternalFeedClient,
        blueprints: [OpportunityBlueprint],
        refreshTime: Date,
        modeLabel: String,
        existingSnapshots: [String: WealthExternalResearchSnapshot]
    ) async -> WealthExternalSourceRefreshResult {
        let providerMode = effectiveProviderMode(for: client.kind, modeLabel: modeLabel)

        guard isEnabled(client.kind) else {
            let snapshots = blueprints.map { blueprint in
                refreshedSnapshot(
                    for: blueprint,
                    existing: existingSnapshots[researchKey(for: blueprint)],
                    source: WealthExternalResearchValue(
                        kind: client.kind,
                        value: 0,
                        state: .off,
                        updatedAt: refreshTime,
                        detail: "Source disabled."
                    ),
                    refreshTime: refreshTime
                )
            }

            return WealthExternalSourceRefreshResult(
                snapshots: snapshots,
                state: .off,
                updatedAt: refreshTime,
                detail: "Source disabled."
            )
        }

        let remoteValues = await fetchRemoteValues(
            for: client.kind,
            blueprints: blueprints,
            modeLabel: modeLabel,
            refreshTime: refreshTime
        )

        let snapshots = blueprints.map { blueprint in
            let key = researchKey(for: blueprint)
            let sourceValue: WealthExternalResearchValue

            if let fetched = remoteValues.valuesByKey[key] {
                sourceValue = WealthExternalResearchValue(
                    kind: client.kind,
                    value: fetched.value,
                    state: providerMode == .mockTest ? .cached : .freshOnline,
                    updatedAt: fetched.updatedAt ?? refreshTime,
                    detail: providerMode == .mockTest ? "Mock/test provider value." : "Fresh online provider value."
                )
            } else if providerMode == .mockTest,
                      let cached = existingSnapshots[key]?.source(for: client.kind),
                      let cachedAt = cached.updatedAt,
                      refreshTime.timeIntervalSince(cachedAt) <= client.kind.cacheTTL,
                      cached.state != .off {
                sourceValue = WealthExternalResearchValue(
                    kind: client.kind,
                    value: cached.value,
                    state: .cached,
                    updatedAt: cachedAt,
                    detail: remoteValues.errorDetail ?? "Using cached provider value."
                )
            } else {
                let fallbackValue = client.signal(for: blueprint).value(for: client.kind)
                sourceValue = WealthExternalResearchValue(
                    kind: client.kind,
                    value: fallbackValue,
                    state: .syntheticFallback,
                    updatedAt: refreshTime,
                    detail: remoteValues.errorDetail ?? "Using synthetic fallback."
                )
            }

            return refreshedSnapshot(
                for: blueprint,
                existing: existingSnapshots[key],
                source: sourceValue,
                refreshTime: refreshTime
            )
        }

        let state: WealthExternalSignalState
        if snapshots.contains(where: { $0.source(for: client.kind)?.state == .freshOnline }) {
            state = .freshOnline
        } else if snapshots.contains(where: { $0.source(for: client.kind)?.state == .cached }) {
            state = .cached
        } else if snapshots.contains(where: { $0.source(for: client.kind)?.state == .syntheticFallback }) {
            state = .syntheticFallback
        } else {
            state = .unavailable
        }

        return WealthExternalSourceRefreshResult(
            snapshots: snapshots,
            state: state,
            updatedAt: refreshTime,
            detail: remoteValues.errorDetail ?? {
                switch state {
                case .freshOnline:
                    return "Fresh online provider values received."
                case .cached:
                    return "Provider fetch missed; cached values retained."
                case .syntheticFallback:
                    return "Provider unavailable; synthetic fallback in use."
                case .unavailable:
                    return "No provider data or fallback available."
                case .off:
                    return "Source disabled."
                }
            }()
        )
    }

    private func refreshedSnapshot(
        for blueprint: OpportunityBlueprint,
        existing: WealthExternalResearchSnapshot?,
        source: WealthExternalResearchValue,
        refreshTime: Date
    ) -> WealthExternalResearchSnapshot {
        var sources = existing?.sources.filter { $0.kind != source.kind } ?? []
        sources.append(source)
        sources.sort { $0.kind.rawValue < $1.kind.rawValue }

        return WealthExternalResearchSnapshot(
            key: researchKey(for: blueprint),
            symbol: blueprint.symbol,
            market: blueprint.market,
            sources: sources,
            lastUpdatedAt: refreshTime
        )
    }

    private func fetchRemoteValues(
        for kind: WealthExternalResearchKind,
        blueprints: [OpportunityBlueprint],
        modeLabel: String,
        refreshTime: Date
    ) async -> WealthExternalRemoteFetchResult {
        switch effectiveProviderMode(for: kind, modeLabel: modeLabel) {
        case .syntheticFallback:
            return WealthExternalRemoteFetchResult(
                valuesByKey: [:],
                errorDetail: "Synthetic fallback forced by provider mode."
            )
        case .mockTest:
            let valuesByKey = Dictionary(uniqueKeysWithValues: blueprints.map { blueprint in
                let signal = WealthExternalBatchSignal(
                    symbol: blueprint.symbol,
                    market: blueprint.market,
                    value: mockValue(for: kind, blueprint: blueprint),
                    updatedAt: refreshTime
                )
                return (wealthRefreshIdentityKey(symbol: blueprint.symbol, market: blueprint.market), signal)
            })
            return WealthExternalRemoteFetchResult(
                valuesByKey: valuesByKey,
                errorDetail: "Mock/test provider values in use."
            )
        case .liveEndpoint:
            break
        }

        guard let endpoint = endpoint(for: kind) else {
            return WealthExternalRemoteFetchResult(
                valuesByKey: [:],
                errorDetail: "No \(kind.displayName) endpoint configured."
            )
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = WealthExternalBatchRequest(
            requestedAt: refreshTime,
            source: kind.rawValue,
            mode: modeLabel,
            securities: blueprints.map {
                WealthExternalBatchSecurity(
                    symbol: $0.symbol,
                    market: $0.market,
                    sector: $0.sector,
                    price: $0.price
                )
            }
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  200..<300 ~= httpResponse.statusCode else {
                return WealthExternalRemoteFetchResult(
                    valuesByKey: [:],
                    errorDetail: "\(kind.displayName) endpoint returned a non-success status."
                )
            }

            let payload = try JSONDecoder().decode(WealthExternalBatchResponse.self, from: data)
            let valuesByKey = Dictionary(uniqueKeysWithValues: payload.signals.map { signal in
                let key = wealthRefreshIdentityKey(symbol: signal.symbol, market: signal.market)
                return (key, signal)
            })

            return WealthExternalRemoteFetchResult(valuesByKey: valuesByKey, errorDetail: nil)
        } catch {
            return WealthExternalRemoteFetchResult(
                valuesByKey: [:],
                errorDetail: "\(kind.displayName) fetch failed: \(error.localizedDescription)"
            )
        }
    }

    private func effectiveProviderMode(
        for kind: WealthExternalResearchKind,
        modeLabel: String
    ) -> WealthExternalProviderMode {
        let configuredMode = mode(for: kind)
        let normalizedModeLabel = modeLabel.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let isNormalLiveScan = ["STARTUP", "QUICK", "SOFT", "HEAVY", "DEEP"].contains(normalizedModeLabel)

        guard isNormalLiveScan, endpoint(for: kind) != nil else {
            return configuredMode
        }

        return .liveEndpoint
    }

    private func mockValue(for kind: WealthExternalResearchKind, blueprint: OpportunityBlueprint) -> Double {
        let symbolLift = Double(abs(blueprint.symbol.hashValue % 9))

        switch kind {
        case .optionsFlow:
            return min(99, 72 + symbolLift)
        case .darkPool:
            return min(99, 68 + symbolLift)
        case .insider:
            return min(99, 61 + symbolLift)
        case .filing13F:
            return min(99, 64 + symbolLift)
        case .earningsCalendar:
            return min(99, 22 + symbolLift)
        case .macroCalendar:
            return min(99, 18 + symbolLift)
        }
    }
}

private struct WealthExternalSourceRefreshResult {
    let snapshots: [WealthExternalResearchSnapshot]
    let state: WealthExternalSignalState
    let updatedAt: Date?
    let detail: String
}

private struct WealthExternalRemoteFetchResult {
    let valuesByKey: [String: WealthExternalBatchSignal]
    let errorDetail: String?
}

private struct WealthExternalBatchRequest: Encodable {
    let requestedAt: Date
    let source: String
    let mode: String
    let securities: [WealthExternalBatchSecurity]
}

private struct WealthExternalBatchSecurity: Encodable {
    let symbol: String
    let market: String
    let sector: String
    let price: Double
}

private struct WealthExternalBatchResponse: Decodable {
    let signals: [WealthExternalBatchSignal]
}

private struct WealthExternalBatchSignal: Decodable {
    let symbol: String
    let market: String
    let value: Double
    let updatedAt: Date?
}
