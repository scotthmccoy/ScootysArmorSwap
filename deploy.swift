#!/usr/bin/env swift

import Foundation

// swiftlint:disable log_usage
@discardableResult func simpleShell(_ command: String) -> String {
	let tuple = shell(command)
	guard let ret = tuple.0 else {
		return ""
	}

	return ret
}

@discardableResult func shell(_ command: String) -> (String?, Int32) {
	let task = Process()

	task.launchPath = "/bin/zsh"
	task.arguments = ["-c", command]

	let pipe = Pipe()
	task.standardOutput = pipe
	task.standardError = pipe
	task.launch()

	let data = pipe.fileHandleForReading.readDataToEndOfFile()
	let output = String(data: data, encoding: .utf8)
	task.waitUntilExit()
	return (output, task.terminationStatus)
}

// Copy the structure to factorio
simpleShell("rsync -av --exclude=\".*\" ../scootys-armor-swap/ ~/Library/Application\\ Support/factorio/mods/scootys-armor-swap")

// Replace DEBUG_BUILD_TIME with the current dateTime
let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "EEE, MMM d - h:mm a"
let strDate = dateFormatter.string(from: Date())


simpleShell("sed -i '' \"s/DEBUG_BUILD_TIME/\(strDate)/g\" ~/Library/Application\\ Support/factorio/mods/scootys-armor-swap/logging.lua")

simpleShell("open ~/Library/Application\\ Support/factorio/mods")

print("Reload the save and run the following: tail -f ~/Library/Application\\ Support/factorio/factorio-current.log")
simpleShell("say done")
