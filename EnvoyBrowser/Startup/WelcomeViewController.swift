//
//  WelcomeViewController.swift
//  EnvoyBrowser
//
//  Created by Benjamin Erhart on 02.05.23.
//  Copyright © 2023 Tigas Ventures, LLC (Mike Tigas)
//
//  This file is part of Envoy Browser. See LICENSE file for redistribution terms.
//

import UIKit

class WelcomeViewController: UIViewController {

	@IBOutlet weak var titleLb: UILabel! {
		didSet {
			titleLb.text = String(format: NSLocalizedString("Welcome to %@", comment: "Placeholder is 'Envoy Browser'"), Bundle.main.displayName)
		}
	}

	@IBOutlet weak var bodyLb: UILabel! {
		didSet {
			bodyLb.text = NSLocalizedString("You're one step closer to private browsing.", comment: "")
		}
	}

	@IBOutlet weak var nextBt: UIButton! {
		didSet {
			nextBt.setTitle(NSLocalizedString("Next", comment: ""))
		}
	}

	@IBAction
	func next() {
		Settings.didWelcome = true

		view.sceneDelegate?.show(nil)
	}
}
