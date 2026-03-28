//
//  OpenSkyBookApp.swift
//  OpenSkyBook
//
//  Created by M E on 29/3/2026.
//

import SwiftUI

@main
struct OpenSkyBookApp: App {
    @AppStorage("openskybook.disclaimer.accepted_version") private var acceptedDisclaimerVersion = ""
    @AppStorage("openskybook.disclaimer.do_not_show_again") private var doNotShowAgain = false
    @State private var isDisclaimerPresented = false

    private static let disclaimerVersion = "2026.1"

    private var requiresMandatoryDisclaimer: Bool {
        acceptedDisclaimerVersion != Self.disclaimerVersion || !doNotShowAgain
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                onShowDisclaimer: {
                    isDisclaimerPresented = true
                }
            )
            .sheet(isPresented: $isDisclaimerPresented) {
                DisclaimerAcknowledgmentView(
                    requiresAcknowledgment: requiresMandatoryDisclaimer,
                    acceptedVersion: acceptedDisclaimerVersion,
                    currentVersion: Self.disclaimerVersion,
                    doNotShowAgain: doNotShowAgain,
                    onContinue: { shouldSuppressFutureDisplay in
                        acceptedDisclaimerVersion = Self.disclaimerVersion
                        doNotShowAgain = shouldSuppressFutureDisplay
                        isDisclaimerPresented = false
                    },
                    onClose: {
                        isDisclaimerPresented = false
                    }
                )
                .interactiveDismissDisabled(requiresMandatoryDisclaimer)
            }
            .task {
                if requiresMandatoryDisclaimer {
                    isDisclaimerPresented = true
                }
            }
        }
    }
}

private struct DisclaimerAcknowledgmentView: View {
    let requiresAcknowledgment: Bool
    let acceptedVersion: String
    let currentVersion: String
    let doNotShowAgain: Bool
    let onContinue: (Bool) -> Void
    let onClose: () -> Void

    @State private var hasAccepted = false
    @State private var suppressFutureDisplay = false

    private var isMajorUpdateNotice: Bool {
        !acceptedVersion.isEmpty && acceptedVersion != currentVersion
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Important Advisory Disclaimer")
                        .font(.title.weight(.semibold))
                    Text(isMajorUpdateNotice ? "Please review and acknowledge the latest advisory notice." : "Please review this advisory notice before using the application.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !requiresAcknowledgment {
                    Button("Close") {
                        onClose()
                    }
                }
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    disclaimerSection(
                        title: "Core Disclaimer",
                        bodyText: "This application provides situational awareness tools and advisory information only.",
                        bullets: [
                            "It does not replace visual line-of-sight requirements",
                            "It does not replace official aviation sources such as CASA or Airservices Australia",
                            "It does not replace pilot responsibility or judgement",
                            "Data presented, including ADS-B, weather, NOTAMs, airspace, and hazard layers, may be incomplete, delayed, or inaccurate",
                            "Not all aircraft transmit ADS-B, and not all hazards are represented",
                            "Always maintain visual awareness, comply with applicable regulations, and verify information using official sources where required"
                        ]
                    )

                    disclaimerSection(
                        title: "Responsibility Statement",
                        bodyText: "By using this application, you acknowledge that:",
                        bullets: [
                            "You are solely responsible for the safe operation of your aircraft",
                            "You will not rely solely on this application for safety-critical decisions",
                            "You understand the limitations of all data presented"
                        ]
                    )

                    disclaimerSection(
                        title: "Limitation of Liability",
                        bodyText: "The developers of this application accept no liability for:",
                        bullets: [
                            "Loss, damage, or injury",
                            "Regulatory violations",
                            "Decisions made based on this application",
                            "Use of this application is at your own risk"
                        ]
                    )

                    Text("Regional reminder: refer to CASA regulations and other official Australian aviation guidance where applicable.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Toggle("I understand and accept", isOn: $hasAccepted)

            Toggle("Do not show again", isOn: $suppressFutureDisplay)
                .disabled(!hasAccepted)
                .onAppear {
                    suppressFutureDisplay = doNotShowAgain
                }

            HStack {
                Spacer()
                Button("Continue") {
                    onContinue(suppressFutureDisplay)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!hasAccepted)
            }
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 680)
    }

    private func disclaimerSection(title: String, bodyText: String, bullets: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(bodyText)
                .font(.body)
            ForEach(bullets, id: \.self) { bullet in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                    Text(bullet)
                }
                .font(.body)
            }
        }
    }
}
