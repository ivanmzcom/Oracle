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
                .fontWeight(.semibold)

            Spacer()

            Text("\(count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(.systemGray5))
                .clipShape(Capsule())
        }
    }
}

#Preview {
    SectionHeaderView(title: "Disponibles", count: 5)
        .padding()
}
