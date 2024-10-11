//
//  Settings.swift
//  EnvoyBrowser
//
//  Created by Benjamin Erhart on 18.10.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Envoy Browser. See LICENSE file for redistribution terms.
//

import UIKit

struct SearchEngine: Equatable {

	enum EngineType: Int {
		case builtIn
		case custom
	}


	let name: String

	let type: EngineType

	var details: Details? {
		switch type {
		case .builtIn:
			return Settings.builtInSearchEngines[name]

		case .custom:
			return Settings.customSearchEngines[name]
		}
	}


	func set(details: Details?) {
		switch type {
		case .custom:
			Settings.customSearchEngines[name] = details

		default:
			// Default engines cannot be changed.
			break
		}
	}


	struct Details: Codable {

		enum CodingKeys: String, CodingKey {
			case searchUrl = "search_url"
			case homepageUrl = "homepage_url"
			case autocompleteUrl = "autocomplete_url"
			case postParams = "post_params"
		}


		let searchUrl: String?

		let homepageUrl: String?

		let autocompleteUrl: String?

		let postParams: [String: String]?


		init(searchUrl: String? = nil, homepageUrl: String? = nil, autocompleteUrl: String? = nil, postParams: [String : String]? = nil) {
			self.searchUrl = searchUrl
			self.homepageUrl = homepageUrl
			self.autocompleteUrl = autocompleteUrl
			self.postParams = postParams
		}

		init(from dict: [String: Any]) {
			searchUrl = dict[CodingKeys.searchUrl.rawValue] as? String
			homepageUrl = dict[CodingKeys.homepageUrl.rawValue] as? String
			autocompleteUrl = dict[CodingKeys.autocompleteUrl.rawValue] as? String
			postParams = dict[CodingKeys.postParams.rawValue] as? [String: String]
		}


		func toDict() -> [String: Any] {
			var dict = [String: Any]()

			if let searchUrl = searchUrl {
				dict[CodingKeys.searchUrl.rawValue] = searchUrl
			}

			if let homepageUrl = homepageUrl {
				dict[CodingKeys.homepageUrl.rawValue] = homepageUrl
			}

			if let autocompleteUrl = autocompleteUrl {
				dict[CodingKeys.autocompleteUrl.rawValue] = autocompleteUrl
			}

			if let postParams = postParams {
				dict[CodingKeys.postParams.rawValue] = postParams
			}

			return dict
		}
	}
}

enum TabSecurityLevel: String, CustomStringConvertible {

	case alwaysRemember = "always_remember"
	case forgetOnShutdown = "forget_on_shutdown"
	case clearOnBackground = "clear_on_background"

	var description: String {
		switch self {
		case .alwaysRemember:
			return NSLocalizedString("Remember Tabs", comment: "Tab security level")

		case .forgetOnShutdown:
			return NSLocalizedString("Forget at Shutdown", comment: "Tab security level")

		default:
			return NSLocalizedString("Forget in Background", comment: "Tab security level")
		}
	}
}


@objcMembers
class Settings {

	open class var defaults: UserDefaults? {
		UserDefaults.standard
	}

	class var stateRestoreLock: Bool {
		get {
			UserDefaults.standard.bool(forKey: "state_restore_lock")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "state_restore_lock")
		}
	}

	/**
	 Don't show this for updating 2.x users. Reuse an old key to achieve this.
	 */
	class var didWelcome: Bool {
		get {
			UserDefaults.standard.bool(forKey: "did_intro")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "did_intro")
		}
	}

	class var bookmarkFirstRunDone: Bool {
		get {
			UserDefaults.standard.bool(forKey: "did_first_run_bookmarks")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "did_first_run_bookmarks")
		}
	}

	class var searchEngine: SearchEngine {
		get {
			let type = SearchEngine.EngineType(rawValue: UserDefaults.standard.integer(forKey: "search_engine_type")) ?? .builtIn

			let name = UserDefaults.standard.object(forKey: "search_engine") as? String

			if name == nil, let defaultEngine = searchEngines.first {
				return defaultEngine
			}

			return SearchEngine(name: name ?? "", type: type)
		}
		set {
			UserDefaults.standard.set(newValue.name, forKey: "search_engine")
			UserDefaults.standard.set(newValue.type.rawValue, forKey: "search_engine_type")
		}
	}

	class var searchEngines: [SearchEngine] {
		return builtInSearchEngines.keys.sorted().map { SearchEngine(name: $0, type: .builtIn) }
			+ customSearchEngines.keys.sorted().map({ SearchEngine(name: $0, type: .custom) })
	}

	fileprivate static let builtInSearchEngines: [String: SearchEngine.Details] = {
		if let url = Bundle.main.url(forResource: "SearchEngines.plist", withExtension: nil),
		   let data = try? Data(contentsOf: url),
		   let searchEngines = try? PropertyListDecoder().decode([String: SearchEngine.Details].self, from: data)
		{
			return searchEngines
		}

		return [:]
	}()

	fileprivate class var customSearchEngines: [String: SearchEngine.Details] {
		get {
			(UserDefaults.standard.object(forKey: "custom_search_engines") as? [String: [String: Any]])?.mapValues({
				SearchEngine.Details(from: $0)
			}) ?? [:]
		}
		set {
			UserDefaults.standard.set(newValue.mapValues({ $0.toDict() }), forKey: "custom_search_engines")
		}
	}

	class var searchLive: Bool {
		get {
			UserDefaults.standard.bool(forKey: "search_engine_live")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "search_engine_live")
		}
	}

	class var searchLiveStopDot: Bool {
		get {
			// Defaults to true!
			if UserDefaults.standard.object(forKey: "search_engine_stop_dot") == nil {
				return true
			}

			return UserDefaults.standard.bool(forKey: "search_engine_stop_dot")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "search_engine_stop_dot")
		}
	}

	class var hideContent: Bool {
		get {
			UserDefaults.standard.object(forKey: "hide_content") == nil
				? true
				: UserDefaults.standard.bool(forKey: "hide_content")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "hide_content")
		}
	}

	/**
	 The successor of Do-Not-Track is "Global Privacy Control".

	 https://globalprivacycontrol.github.io/gpc-spec/
	 */
	class var sendGpc: Bool {
		get {
			return UserDefaults.standard.bool(forKey: "send_gpc")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "send_gpc")
		}
	}

	class var tabSecurity: TabSecurityLevel {
		get {
			if let value = UserDefaults.standard.object(forKey: "tab_security") as? String,
				let level = TabSecurityLevel(rawValue: value) {

				return level
			}

			return .clearOnBackground
		}
		set {
			UserDefaults.standard.set(newValue.rawValue, forKey: "tab_security")
		}
	}

	class var openTabs: [URL]? {
		get {
			if let data = UserDefaults.standard.object(forKey: "open_tabs") as? Data {
				return try? NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, NSURL.self], from: data) as? [URL]
			}

			return nil
		}
		set {
			if let newValue = newValue {
				let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true)
				UserDefaults.standard.set(data, forKey: "open_tabs")
			}
			else {
				UserDefaults.standard.removeObject(forKey: "open_tabs")
			}
		}
	}

	class var muteWithSwitch: Bool {
		get {
			// Defaults to true!
			if UserDefaults.standard.object(forKey: "mute_with_switch") == nil {
				return true
			}

			return UserDefaults.standard.bool(forKey: "mute_with_switch")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "mute_with_switch")

			AppDelegate.shared?.adjustMuteSwitchBehavior()
		}
	}

	class var disableBookmarksOnStartPage: Bool {
		get {
			UserDefaults.standard.bool(forKey: "disable_bookmarks_on_start_page")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "disable_bookmarks_on_start_page")
		}
	}

	class var thirdPartyKeyboards: Bool {
		get {
			UserDefaults.standard.bool(forKey: "third_party_keyboards")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "third_party_keyboards")
		}
	}

	class var nextcloudServer: String? {
		get {
			UserDefaults.standard.string(forKey: "nextcloud_server")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "nextcloud_server")
		}
	}

	class var nextcloudUsername: String? {
		get {
			UserDefaults.standard.string(forKey: "nextcloud_username")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "nextcloud_username")
		}
	}

	class var nextcloudPassword: String? {
		get {
			UserDefaults.standard.string(forKey: "nextcloud_password")
		}
		set {
			UserDefaults.standard.set(newValue, forKey: "nextcloud_password")
		}
	}
}
