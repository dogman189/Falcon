//
//  ContentView.swift
//  Falcon
//
//  Created by Aanetra Vaidya on 11/15/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedClient: BundledClient?
    @State private var quitRevealed = false
    @State private var quitHideTask: Task<Void, Never>?
    @State private var clientFailure: String?

    var body: some View {
        Group {
            if let selectedClient {
                if let clientFailure {
                    failureView(for: selectedClient, message: clientFailure)
                } else if let fileURL = selectedClient.url {
                    EaglerWebView(fileURL: fileURL) { message in
                        clientFailure = message
                    }
                    .ignoresSafeArea()
                    .background(.black)
                    .overlay(alignment: .topLeading) {
                        ZStack(alignment: .topLeading) {
                            Color.clear
                                .frame(width: 140, height: 90)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 20)
                                        .onEnded { _ in
                                            toggleQuitReveal()
                                        }
                                )

                            if quitRevealed {
                                quitButton
                            }
                        }
                    }
                } else {
                    failureView(
                        for: selectedClient,
                        message: "The bundled file for \(selectedClient.name) is missing."
                    )
                }
            } else {
                clientSelector
            }
        }
        .onChange(of: selectedClient) { _, _ in
            hideQuit()
        }
        .task {
            openDebugClientIfRequested()
        }
    }

    private var quitButton: some View {
        Button {
            hideQuit()
            clientFailure = nil
            selectedClient = nil
        } label: {
            Text("Quit")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .background(Color.black.opacity(0.25))
        .clipShape(Capsule())
        .foregroundStyle(.white.opacity(0.9))
        .padding(.leading, 24)
        .padding(.top, 8)
    }

    private func toggleQuitReveal() {
        withAnimation(.easeInOut(duration: 0.15)) {
            quitRevealed.toggle()
        }
        if quitRevealed {
            scheduleQuitAutoHide()
        } else {
            quitHideTask?.cancel()
        }
    }

    private func scheduleQuitAutoHide() {
        quitHideTask?.cancel()
        quitHideTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.15)) {
                quitRevealed = false
            }
        }
    }

    private func hideQuit() {
        quitHideTask?.cancel()
        quitHideTask = nil
        quitRevealed = false
    }

    private func failureView(for client: BundledClient, message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.yellow)

            Text("\(client.name) stopped")
                .font(.title2.bold())

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 560)

            HStack(spacing: 12) {
                Button("Try again") {
                    clientFailure = nil
                }
                .buttonStyle(.borderedProminent)

                Button("Back to clients") {
                    clientFailure = nil
                    selectedClient = nil
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .foregroundStyle(.white)
        .ignoresSafeArea()
    }

    private var clientSelector: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(BundledClient.all) { client in
                        Button {
                            clientFailure = nil
                            selectedClient = client
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(client.name)
                                        .foregroundStyle(.primary)
                                    if let note = client.note {
                                        Text(note)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if client.url == nil {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .disabled(client.url == nil)
                    }
                } header: {
                    Text("Select a client")
                } footer: {
                    Text("Swipe down in the top-left corner to reveal Quit. 26.2 runs in low-memory mode but may still be stopped by iOS; 1.8.8-wasm may need single-thread if it hangs starting the integrated server.")
                }
            }
            .navigationTitle("Falcon")
        }
    }

    private func openDebugClientIfRequested() {
        #if DEBUG
        guard selectedClient == nil else { return }
        let arguments = ProcessInfo.processInfo.arguments
        guard let argument = arguments.first(where: { $0.hasPrefix("--client=") }) else {
            return
        }
        let requested = String(argument.dropFirst("--client=".count))
        guard let client = BundledClient.all.first(where: {
            $0.name == requested || $0.resource == requested
        }) else {
            return
        }
        selectedClient = client
        #endif
    }
}

#Preview {
    ContentView()
}
