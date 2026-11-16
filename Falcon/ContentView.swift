//
//  ContentView.swift
//  Falcon
//
//  Created by Aanetra Vaidya on 11/15/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        EaglerWebView()
            .ignoresSafeArea()
            .background(.black)
    }
}

#Preview {
    ContentView()
}
