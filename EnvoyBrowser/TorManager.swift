//
//  TorManager.swift
//  Orbot
//
//  Created by Benjamin Erhart on 17.05.21.
//  Copyright © 2021 Guardian Project. All rights reserved.
//

import NetworkExtension
import Network
import GreatfireEnvoy


class TorManager {

	enum Status: String, Codable {
		case stopped = "stopped"
		case starting = "starting"
		case started = "started"
	}

	enum Errors: Error, LocalizedError {
		case cookieUnreadable
		case noSocksAddr
		case smartConnectFailed

		var errorDescription: String? {
			switch self {

			case .cookieUnreadable:
				return "Tor cookie unreadable"

			case .noSocksAddr:
				return "No SOCKS port"

			case .smartConnectFailed:
				return "Smart Connect failed"
			}
		}
	}

	static let shared = TorManager()

	static let localhost = "127.0.0.1"

	var status = Status.stopped

	private var envoyRunning: Bool {
		Envoy.shared.proxy != .direct
	}


	func start(_ progressCallback: @escaping (_ progress: Int?) -> Void,
			   _ completion: @escaping (Error?) -> Void)
	{
		status = .starting

		if !envoyRunning {
			Task {
				await Envoy.shared.start(urls: [])

				if Envoy.shared.proxy != .direct {
					status = .started
				}
				else {
					status = .stopped
				}

				completion(nil)
			}
		}
	}

	func stop() {
		status = .stopped

		Envoy.shared.stop()
	}


	// MARK: Private Methods

	private func log(_ message: String) {
		print("[\(String(describing: type(of: self)))] \(message)")
	}
}
