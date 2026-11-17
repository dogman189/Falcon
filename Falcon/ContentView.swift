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

    var body: some View {
        Group {
            if let selectedClient, let fileURL = selectedClient.url {
                EaglerWebView(fileURL: fileURL)
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
                                            quitRevealed = true
                                        }
                                )

                            if quitRevealed {
                                quitButton
                            }
                        }
                    }
                    .onChange(of: selectedClient) { _, _ in
                        quitRevealed = false
                    }
            } else {
                clientSelector
            }
        }
    }

    private var quitButton: some View {
        Button {
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

    private var clientSelector: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(BundledClient.all) { client in
                        Button {
                            selectedClient = client
                        } label: {
                            HStack {
                                Text(client.name)
                                    .foregroundStyle(.primary)
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
                    Text("The selected client opens full screen. Quit and reopen Falcon to return to this list.")
                }
            }
            .navigationTitle("Falcon")
        }
    }
}

#Preview {
    ContentView()
}
