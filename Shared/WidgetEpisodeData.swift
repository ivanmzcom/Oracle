//
//  WidgetEpisodeData.swift
//  Shared between Trakt app and TraktWidget
//

import Foundation

struct WidgetEpisodeData: Codable, Identifiable {
    let showTitle: String
    let episodeCode: String
    let posterURL: String?
    var id: String { "\(showTitle)-\(episodeCode)" }
}
