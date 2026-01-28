//
//  User.swift
//  Trakt
//

import Foundation

struct TraktUser: Codable {
    let username: String
    let isPrivate: Bool
    let name: String?
    let vip: Bool?
    let vipEp: Bool?
    let location: String?
    let about: String?
    let joinedAt: Date?
    let images: UserImages?

    enum CodingKeys: String, CodingKey {
        case username
        case isPrivate = "private"
        case name
        case vip
        case vipEp = "vip_ep"
        case location
        case about
        case joinedAt = "joined_at"
        case images
    }
}

struct UserImages: Codable {
    let avatar: UserAvatar?
}

struct UserAvatar: Codable {
    let full: String?
}

struct UserSettings: Codable {
    let user: TraktUser
}
