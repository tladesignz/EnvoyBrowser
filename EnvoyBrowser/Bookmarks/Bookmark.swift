//
//  Bookmark.swift
//  EnvoyBrowser
//
//  Created by Benjamin Erhart on 08.10.19.
//  Copyright © 2012 - 2023, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Envoy Browser. See LICENSE file for redistribution terms.
//


import UIKit
import FavIcon

@objc
@objcMembers
open class Bookmark: NSObject {

	static let defaultIcon = UIImage(named: "default-icon")!

	private static let keyBookmarks = "bookmarks"
	private static let keyVersion = "version"
	private static let keyName = "name"
	private static let keyUrl = "url"
	private static let keyIcon = "icon"
	private static let keyLastUpdated = "last_updated"

	private static let version = 2

	private static var root = FileManager.default.docsDir
	private static var bookmarkFilePath = root?.appendingPathComponent("bookmarks.plist")

	private static let defaultBookmarks: [Bookmark] = {
		var defaults = [Bookmark]()

		return defaults
	}()

	private static var startPageNeedsUpdate = true

	static var all: [Bookmark] = {

		// Init FavIcon config here, because all code having to do with bookmarks should come along here anyway.
		FavIcon.downloadSession = URLSession.shared

		var bookmarks = [Bookmark]()

		if let path = bookmarkFilePath {
			let data = NSDictionary(contentsOf: path)

			for b in data?[keyBookmarks] as? [NSDictionary] ?? [] {
				bookmarks.append(Bookmark(b))
			}
		}

		return bookmarks
	}()

	class func firstRunSetup() {
		guard !Settings.bookmarkFirstRunDone else {
			return
		}

		// Only set up default list of bookmarks, when there's no others.
		guard all.count < 1 else {
			Settings.bookmarkFirstRunDone = true

			return
		}

		all.append(contentsOf: defaultBookmarks)

		store()

		DispatchQueue.global(qos: .background).async {
			for bookmark in all {
				bookmark.acquireIcon() { updated in
					if updated {
						store()
					}
				}
			}

			Settings.bookmarkFirstRunDone = true
		}
	}

	class func updateStartPage(force: Bool = false) {
		guard let source = Bundle.main.url(forResource: "start", withExtension: "html") else {
			return
		}

		// Always update after start. Language could have been changed.
		if !startPageNeedsUpdate && !force {
			let fm = FileManager.default

			// If files exist and destination is newer than source, don't do anything. (Upgrades!)
			if let dm = try? fm.attributesOfItem(atPath: URL.start.path)[.modificationDate] as? Date,
				let sm = try? fm.attributesOfItem(atPath: source.path)[.modificationDate] as? Date {

				if dm > sm {
					return
				}
			}
		}

		guard var template = try? String(contentsOf: source) else {
			return
		}

		if Settings.disableBookmarksOnStartPage {
			template = template.replacingOccurrences(of: "{{ bookmarks_table_style }}", with: "display: none")
		}
		else {
			template = template.replacingOccurrences(of: "{{ bookmarks_table_style }}", with: "")

			// Render bookmarks.
			for i in 0 ... 5 {
				let url: URL
				let name: String
				let icon: UIImage

				if all.count > i,
					let tempUrl = all[i].url {

					url = tempUrl

					name = all[i].name ?? url.host!
					icon = all[i].icon ?? Bookmark.defaultIcon
				}
				else {
					// Make sure that the first 6 default bookmarks are available!
					url = defaultBookmarks[i].url!
					name = defaultBookmarks[i].name ?? url.host!
					icon = defaultBookmarks[i].icon ?? Bookmark.defaultIcon
				}

				template = template
					.replacingOccurrences(of: "{{ bookmark_url_\(i) }}", with: url.absoluteString)
					.replacingOccurrences(of: "{{ bookmark_name_\(i) }}", with: name)
					.replacingOccurrences(of: "{{ bookmark_icon_\(i) }}",
						with: "data:image/png;base64,\(icon.pngData()?.base64EncodedString() ?? "")")
			}
		}

		template = template
			.replacingOccurrences(of: "{{ Envoy Browser }}",
								  with: Bundle.main.displayName)
			.replacingOccurrences(of: "{{ Learn more about Envoy Browser }}",
								  with: String(format: NSLocalizedString("Learn more about %@", comment: ""), Bundle.main.displayName))
			.replacingOccurrences(of: "{{ Donate to Envoy Browser }}",
								  with: String(format: NSLocalizedString("Donate to %@", comment: ""), Bundle.main.displayName))
			.replacingOccurrences(of: "{{ Subscribe to Tor Newsletter }}",
								  with: NSLocalizedString("Subscribe to Tor Newsletter", comment: ""))

		try? template.write(to: URL.start, atomically: true, encoding: .utf8)

		startPageNeedsUpdate = false
	}

	@discardableResult
	class func add(_ name: String?, _ url: String) -> Bookmark {
		let bookmark = Bookmark(name: name, url: url)

		all.append(bookmark)

		return bookmark
	}

	@discardableResult
	class func store() -> Bool {
		if let path = bookmarkFilePath {

			// Trigger update of start page when things changed.
			startPageNeedsUpdate = true

			DispatchQueue.main.async {
				for tab in AppDelegate.shared?.allOpenTabs ?? [] {
					if tab.url == URL.start {
						tab.refresh()
					}
				}
			}

			let bookmarks = NSMutableArray()

			for b in all {
				bookmarks.add(b.asDic())
			}

			let data = NSMutableDictionary()
			data[keyBookmarks] = bookmarks
			data[keyVersion] = version
			
			return data.write(to: path, atomically: true)
		}

		return false
	}

	@objc(containsUrl:)
	class func contains(url: URL) -> Bool {
		return all.contains { $0.url == url }
	}

	var name: String?
	var url: URL?

	private var iconName = ""

	private var lastUpdated = Date(timeIntervalSince1970: 0)

	private var _icon: UIImage?
	var icon: UIImage? {
		get {
			if _icon == nil && !iconName.isEmpty,
				let path = Bookmark.root?.appendingPathComponent(iconName).path {

				_icon = UIImage(contentsOfFile: path)
			}

			return _icon
		}
		set {
			_icon = newValue

			// Remove old icon, if it gets deleted.
			if _icon == nil {
				if !iconName.isEmpty,
					let path = Bookmark.root?.appendingPathComponent(iconName) {

					try? FileManager.default.removeItem(at: path)
				}

				iconName = ""
				lastUpdated = Date(timeIntervalSince1970: 0)
			}
			else {
				if iconName.isEmpty {
					iconName = UUID().uuidString
				}

				if let path = Bookmark.root?.appendingPathComponent(iconName),
				   let data = _icon?.pngData()
				{
					do {
						try data.write(to: path)
						lastUpdated = Date()
					}
					catch {
						// Ignored.
					}
				}
			}
		}
	}

	init(name: String? = nil, url: String? = nil, icon: UIImage? = nil) {
		super.init()

		self.name = name

		if let url = url {
			self.url = URL(string: url)
		}

		self.icon = icon
	}

	init(name: String?, url: String?, iconName: String, lastUpdated: Date) {
		super.init()

		self.name = name

		if let url = url {
			self.url = URL(string: url)
		}

		self.iconName = iconName
		self.lastUpdated = lastUpdated
	}

	convenience init(_ dic: NSDictionary) {
		self.init(name: dic[Bookmark.keyName] as? String,
				  url: dic[Bookmark.keyUrl] as? String,
				  iconName: dic[Bookmark.keyIcon] as? String ?? "",
				  lastUpdated: Date(timeIntervalSince1970: dic[Bookmark.keyLastUpdated] as? TimeInterval ?? 0))
	}


	// MARK: Public Methods

	class func icon(for url: URL, _ completion: @escaping (_ image: UIImage?) -> Void) {
		do {
			try FavIcon.downloadPreferred(url, width: 128, height: 128) { result in
				if case let .success(image) = result {
					completion(image)
				}
				else {
					completion(nil)
				}
			}
		}
		catch {
			completion(nil)
		}
	}

	func acquireIcon(_ completion: @escaping (_ updated: Bool) -> Void) {
		if let url = url, lastUpdated < Date() - 60 * 60 * 24 {
			Bookmark.icon(for: url) { image in
				self.icon = image

				completion(true)
			}
		}
		else {
			completion(false)
		}
	}


	// MARK: Private Methods

	private func asDic() -> NSDictionary {
		return NSDictionary(dictionary: [
			Bookmark.keyName: name ?? "",
			Bookmark.keyUrl: url?.absoluteString ?? "",
			Bookmark.keyIcon: iconName,
			Bookmark.keyLastUpdated: lastUpdated.timeIntervalSince1970,
		])
	}
}
