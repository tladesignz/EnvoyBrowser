//
//  BrowsingViewController+UITextFieldDelegate.swift
//  OnionBrowser
//
//  Created by Benjamin Erhart on 06.11.19.
//  Copyright © 2012 - 2024, Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Onion Browser. See LICENSE file for redistribution terms.
//

import UIKit

extension BrowsingViewController: UITextFieldDelegate {

	private static let secureIcon = UIImage(named: "secure")
	private static let insecureIcon = UIImage(named: "insecure")


	// MARK: UITextFieldDelegate

	func textFieldDidBeginEditing(_ textField: UITextField) {
		debug("#textFieldDidBeginEditing")

		updateSearchField()
	}

	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		let search = searchFl?.text

		DispatchQueue.main.async {
			self.liveSearchVc.hide()
			textField.resignFirstResponder()

			// User is shifting to a new place. Probably a good time to clear old data.
			WebsiteStorage.shared.cleanup()

			if let url = self.parseSearch(search) {
				self.debug("#textFieldShouldReturn url=\(url)")

				if let currentTab = self.currentTab {
					currentTab.load(url)
				}
				else {
					self.addNewTab(url)
				}
			}
			else {
				self.debug("#textFieldShouldReturn search=\(String(describing: search))")

				if self.currentTab == nil {
					self.addNewTab()
				}

				self.currentTab?.search(for: search)
			}
		}

		return true
	}

	func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
		debug("#textFieldDidEndEditing")

		liveSearchVc.hide()
		updateSearchField()
	}


	// MARK: Actions

	@IBAction func searchDidChange() {
		guard Settings.searchLive && !(Settings.searchEngine.details?.autocompleteUrl?.isEmpty ?? true) else {
			return
		}

		if parseSearch(searchFl?.text) != nil {
			// That's not a search, that's a valid URL. -> Remove live search results.

			return liveSearchVc.hide()
		}

		if !liveSearchVc.searchOngoing {
			if UIDevice.current.userInterfaceIdiom == .pad {
				present(liveSearchVc, searchFl)
			}
			else {
				addChild(liveSearchVc)

				liveSearchVc.view.translatesAutoresizingMaskIntoConstraints = false
				view.addSubview(liveSearchVc.view)
				liveSearchVc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
				liveSearchVc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
				liveSearchVc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true

				if let searchBar = searchBar {
					liveSearchVc.view.topAnchor.constraint(equalTo: searchBar.bottomAnchor).isActive = true
				}
			}

			liveSearchVc.searchOngoing = true
		}

		liveSearchVc.update(searchFl?.text, tab: currentTab)
	}


	// MARK: Public Methods

	/**
	Renders the `searchFl` depending on if it currently has focus.
	*/
	func updateSearchField() {
		if searchFl?.isFirstResponder ?? false {
			if searchFl?.textAlignment == .natural {
				// Seems already set correctly. Don't mess with it, while user
				// edits it actively!
				return
			}

			searchFl?.text = currentTab?.url.clean?.absoluteString

			// .unlessEditing would be such a great state, if it wouldn't show
			// while editing an empty field. Argh.
			searchFl?.leftViewMode = .never
			searchFl?.rightViewMode = .never

			searchFl?.textAlignment = .natural
		}
		else {
			searchFl?.text = BrowsingViewController.prettyTitle(currentTab?.url)
			searchFl?.leftViewMode = encryptionBt.image(for: .normal) == nil ? .never : .always
			searchFl?.rightViewMode = searchFl?.text?.isEmpty ?? true ? .never : .always

			searchFl?.textAlignment = .center
		}
	}

	class func prettyTitle(_ url: URL?) -> String {
		guard let url = url?.clean else {
			return ""
		}

		if let host = url.host {
			return host.replacingOccurrences(of: #"^www\d*\."#, with: "", options: .regularExpression)
		}

		return url.absoluteString
	}

	/**
	Updates the `encryptionBt`:
	- Show a closed lock icon, when `WebViewTabSecureMode` is `.secure` or `.secureEV`.
	- Show a open lock icon, when mode is `.mixed`.
	- Show no icon, when mode is `.insecure`.
	*/
	func updateEncryptionBt(_ mode: Tab.SecureMode) {
		let encryptionIcon: UIImage?

		switch mode {
		case .secure, .secureEv:
			encryptionIcon = BrowsingViewController.secureIcon

		case .mixed:
			encryptionIcon = BrowsingViewController.insecureIcon

		default:
			encryptionIcon = nil
		}

		encryptionBt.setImage(encryptionIcon, for: .normal)
		searchFl?.leftViewMode = searchFl?.isFirstResponder ?? false || encryptionIcon == nil ? .never : .always
	}


	// MARK: Private Methods

	/**
	Parse a user search.

	- parameter search: The user entry, which could be a (semi-)valid URL or a search engine query.
	- returns: A parsed (and fixed) URL or `nil`, in which case you should treat the string as a search engine query.
	*/
	private func parseSearch(_ search: String?) -> URL? {
		// Must not be empty, must not be the explicit blank page.
		if let search = search,
		   !search.isEmpty
		{
			// Blank page, return that.
			if search.caseInsensitiveCompare(URL.blank.absoluteString) == .orderedSame {
				return URL.blank
			}

			// If credits page, return that.
			if search.caseInsensitiveCompare(URL.aboutOnionBrowser.absoluteString) == .orderedSame {
				return URL.aboutOnionBrowser
			}

			if search.caseInsensitiveCompare(URL.aboutSecurityLevels.absoluteString) == .orderedSame {
				return URL.aboutSecurityLevels
			}

			if search.range(of: #"\s+"#, options: .regularExpression) != nil
				|| !search.contains(".")
			{
				// Search contains spaces or contains no dots. That's really a search!
				return nil
			}

			// We rely on URLComponents parsing style! *Don't* change to URL!
			if let urlc = URLComponents(string: search) {
				let scheme = urlc.scheme?.lowercased() ?? ""

				if scheme.isEmpty {
					// Set missing scheme to HTTP.
					return setHttpsScheme(search)
				}

				if scheme != "about" && scheme != "file" {
					if urlc.host?.isEmpty ?? true
						&& urlc.path.range(of: #"^\d+"#, options: .regularExpression) != nil
					{
						// A scheme, no host, path begins with numbers. Seems like "example.com:1234" was parsed wrongly.
						return setHttpsScheme(search)
					}

					// User has simply entered a valid URL?!?
					return urlc.url
				}

				// Someone wants to try something here. No way.
			}

			// Unparsable.
		}

		//  Return start page.
		return URL.start
	}

	/**
	 Will try to create a URL from the given text. If the resulting URL has a `.onion`  host,
	 it will use the `http` scheme, otherwise, it will use the `https`  scheme.

	 Onion-servers often don't use an additional TLS encryption for their traffic, as Tor already adds
	 6 layers of TLS encryption to it and the last layer is only decrypted at the Onion-server itself, anyway.
	 Hence, technically there's no need for an additional encryption layer.

	 For servers on the clearnet, however, where most of them moved to TLS encryption, we finally want to secure
	 the users by never auto-complete an insecure option. They would need to fall back by hand, then.

	 - parameter search: The search input given by the user, which might resemble some URL.
	 - returns: a URL, if the given `search` argument can be parsed as such.
	 */
	private func setHttpsScheme(_ search: String) -> URL? {
		let url = URL(string: "https://\(search)")

		if url?.host?.lowercased().hasSuffix(".onion") ?? false {
			return URL(string: "http://\(search)")
		}

		return url
	}
}
