//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import open_file_mac
import pasteboard
import screen_retriever
import window_manager

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  OpenFilePlugin.register(with: registry.registrar(forPlugin: "OpenFilePlugin"))
  PasteboardPlugin.register(with: registry.registrar(forPlugin: "PasteboardPlugin"))
  ScreenRetrieverPlugin.register(with: registry.registrar(forPlugin: "ScreenRetrieverPlugin"))
  WindowManagerPlugin.register(with: registry.registrar(forPlugin: "WindowManagerPlugin"))
}
