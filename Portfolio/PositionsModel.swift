//
//  DataModels.swift
//  Portfolio
//
//  Created by Brian Riviere on 2019-12-08.
//  Copyright © 2019 ExtremeBytes Software. All rights reserved.
//

import Foundation

protocol ObjectModel {}


struct PositionsData : Codable, ObjectModel {
    let symbols_requested : Int?
    let symbols_returned : Int?
    let data : [PositionData]?
}

struct PositionData : Codable {
    let symbol : String?
    let name : String?
    let currency : String?
    let price : String?
    let price_open : String?
    let day_high : String?
    let day_low : String?
    let day_change : String?
    let change_pct : String?
    let close_yesterday : String?
    let market_cap : String?
    let volume : String?
    let volume_avg : String?
    let shares : String?
    let stock_exchange_long : String?
    let stock_exchange_short : String?
    let timezone : String?
    let timezone_name : String?
    let gmt_offset : String?
    let last_trade_time : String?
    let pe : String?
    let eps : String?
}

/*
 {
    "symbols_requested":1,
    "symbols_returned":1,
    "data":
         [
             {
                "symbol":"TD.TO",
                 "name":"Toronto-Dominion Bank",
                 "currency":"CAD",
                 "price":"73.43",
                 "price_open":"73.60",
                 "day_high":"73.90",
                 "day_low":"73.31",
                 "52_week_high":"77.96",
                 "52_week_low":"65.56",
                 "day_change":"0.41",
                 "change_pct":"0.56",
                 "close_yesterday":"73.02",
                 "market_cap":"100324030884",
                 "volume":"2351730",
                 "volume_avg":"2696085",
                 "shares":"1812486824",
                 "stock_exchange_long":"Toronto Stock Exchange",
                 "stock_exchange_short":"TSX",
                 "timezone":"EST",
                 "timezone_name":"America/Toronto",
                 "gmt_offset":"-18000",
                 "last_trade_time":"2019-12-06 16:00:00",
                 "pe":"11.67",
                 "eps":"6.29"
             }
        ]
 }
 */
