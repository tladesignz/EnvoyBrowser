//
//  URL+Helpers.swift
//  EnvoyBrowser
//
//  Created by Benjamin Erhart on 21.11.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Envoy Browser. See LICENSE file for redistribution terms.
//

import Foundation

extension URL {

	static let blank = URL(string: "about:blank")!

	static let aboutEnvoyBrowser = URL(string: "about:envoy-browser")!
	static let credits = Bundle.main.url(forResource: "credits", withExtension: "html")!

	static let aboutSecurityLevels = URL(string: "about:security-levels")!
	static let securityLevels = Bundle.main.url(forResource: "security-levels", withExtension: "html")!

	static let start = FileManager.default.cacheDir!.appendingPathComponent("start.html")

	var withFixedScheme: URL? {
		switch scheme?.lowercased() {
		case "onionhttp":
			var urlc = URLComponents(url: self, resolvingAgainstBaseURL: true)
			urlc?.scheme = "http"

			return urlc?.url

		case "onionhttps":
			var urlc = URLComponents(url: self, resolvingAgainstBaseURL: true)
			urlc?.scheme = "https"

			return urlc?.url

		default:
			return self
		}
	}

	var real: URL {
		switch self {
		case URL.aboutEnvoyBrowser:
			return URL.credits

		case URL.aboutSecurityLevels:
			return URL.securityLevels

		default:
			return self
		}
	}

	var clean: URL? {
		switch self {
		case URL.credits:
			return URL.aboutEnvoyBrowser

		case URL.securityLevels:
			return URL.aboutSecurityLevels

		case URL.start:
			return nil

		default:
			return self
		}
	}

	var isSpecial: Bool {
		switch scheme {
		case "http", "https", "onionhttp", "onionhttps":
			break

		default:
			return true
		}

		switch self {
		case URL.blank, URL.aboutEnvoyBrowser, URL.credits, URL.aboutSecurityLevels, URL.securityLevels, URL.start:
			return true

		default:
			return false
		}
	}

	var isSearchable: Bool {
		switch self {
		case URL.blank, URL.start:
			return false

		default:
			return true
		}
	}

	var exists: Bool {
		(try? self.checkResourceIsReachable()) ?? false
	}
}

@objc
extension NSURL {

	var withFixedScheme: NSURL? {
		return (self as URL).withFixedScheme as NSURL?
	}
}
