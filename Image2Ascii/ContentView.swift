//
//  ContentView.swift
//  Image2Ascii
//
//  Created by Quin Scacheri on 11/26/22.
//

import SwiftUI

struct ContentView: View {
    @State var output: String = ""
    @State var image: NSImage?
    @State var scale: Double = 1
    @State var converter = Converter()
    var body: some View {
        ScrollView {
            HStack {
                VStack {
                    if let image = image {
                        Image(nsImage: image)
                    }
                    if !output.isEmpty {
                        Text(output)
                            .font(.custom("Courier", size: 4))
                        Button("Copy") {
                            let pasteboard = NSPasteboard.general
                            pasteboard.declareTypes([NSPasteboard.PasteboardType.string], owner: nil)
                            pasteboard.setString(output, forType: NSPasteboard.PasteboardType.string)
                        }
                    }

                    Button("Open") {
                        let dialog = NSOpenPanel()
                        dialog.canChooseDirectories = false
                        if dialog.runModal() == NSApplication.ModalResponse.OK {
                            let result = dialog.url // Pathname of the file
                            if let result = result {
                                guard let newImage = NSImage(contentsOf: result) else { fatalError() }
                                self.image = newImage
                                converter.convert(image: newImage, scale: 1) { ascii in
                                    output = ascii ?? ""
                                }
                            }

                        } else {
                            // User clicked on "Cancel"
                            return
                        }
                    }
                    Slider(value: $scale, in: 0.1 ... 1) { _ in
                        if let image = image {
                            converter.convert(image: image, scale: scale) { ascii in
                                output = ascii ?? ""
                            }
                        }
                    }
                }
                Spacer()
            }

        }.background(.white)
            .frame(idealWidth: .infinity, idealHeight: .infinity)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
