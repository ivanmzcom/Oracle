//
//  SectionHeaderView.swift
//  Trakt
//

import SwiftUI

struct SectionHeaderView: View {
    let title: String
    let count: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)

            Spacer()

            Text("\(count)")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Capsule())
        }
    }
}

#Preview {
    SectionHeaderView(title: "Disponibles", count: 5)
        .padding()
}
