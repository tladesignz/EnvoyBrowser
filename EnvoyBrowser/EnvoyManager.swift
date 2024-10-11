//
//  EnvoyManager.swift
//  Orbot
//
//  Created by Benjamin Erhart on 17.05.21.
//  Copyright © 2021 Guardian Project. All rights reserved.
//

import NetworkExtension
import Network
import GreatfireEnvoy


class EnvoyManager {

	enum Status: String, Codable {
		case stopped = "stopped"
		case starting = "starting"
		case started = "started"
	}

	static let shared = EnvoyManager()

	var status = Status.stopped


	func start(_ progressCallback: @escaping (_ progress: Int?) -> Void,
			   _ completion: @escaping (Error?) -> Void)
	{
		status = .starting

		Task {
			let proxies = Proxy.fetch()
			print("[\(String(describing: type(of: self)))] proxies=\(proxies)")

			await Envoy.shared.start(urls: proxies.map({ $0.url }), testDirect: false)

			print("[\(String(describing: type(of: self)))] selected=\(Envoy.shared.proxy)")

			if Envoy.shared.proxy != .direct {
				status = .started
			}
			else {
				status = .stopped
			}

			completion(nil)
		}
	}

	func stop() {
		status = .stopped

		Envoy.shared.stop()
	}

	/**
	 Check's Envoy's status, and if not working, returns a view controller to show instead of the browser UI.

	 - returns: A view controller to show instead of the browser UI, if status is not good.
	 */
	func checkStatus() -> UIViewController? {
		if !Settings.didWelcome {
			return WelcomeViewController()
		}

		if status == .started {
			return nil
		}

		// No Envoy proxy running. Let the user start it!
		return StartEnvoyViewController()
	}

	// MARK: Private Methods

	private func log(_ message: String) {
		print("[\(String(describing: type(of: self)))] \(message)")
	}
}
