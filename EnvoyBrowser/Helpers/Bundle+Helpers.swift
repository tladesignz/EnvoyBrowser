//
//  Bundle+displayName.swift
//  OnionBrowser2
//
//  Created by Benjamin Erhart on 01.10.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import Foundation

public extension Bundle {

    var displayName: String {
        return object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? object(forInfoDictionaryKey: kCFBundleNameKey as String) as? String
            ?? ""
    }

	var version: String {
		return object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
			?? "unknown"
	}

	var activityType: String? {
		(infoDictionary?["NSUserActivityTypes"] as? Array)?.first
	}
}
