//
//  ContentView.swift
//  Falcon
//
//  Created by Aanetra Vaidya on 11/15/26.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedClient: BundledClient?

    var body: some View {
        Group {
            if let selectedClient, let fileURL = selectedClient.url {
                EaglerWebView(fileURL: fileURL)
                    .ignoresSafeArea()
                    .background(.black)
                    .overlay(alignment: .topLeading) {
                        quitButton
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
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .background(Color.black.opacity(0.45))
        .clipShape(Capsule())
        .foregroundStyle(.white)
        .padding(.leading, 12)
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
