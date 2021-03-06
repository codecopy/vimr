/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa
import RxSwift

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  @IBOutlet weak var window: NSWindow!

  @IBOutlet weak var clientTextField: NSTextField!

  @IBOutlet weak var serverTextView: NSTextView!
  @IBOutlet weak var clientTextView: NSTextView!

  private let server = RxMessagePortServer()
  private let client = RxMessagePortClient()

  private var msgid = Int32(0)

  private let disposeBag = DisposeBag()

  @IBAction func serverStop(sender: Any?) {
    self.server.stop().subscribe().disposed(by: self.disposeBag)
  }

  @IBAction func clientStop(sender: Any?) {
    self.client.stop().subscribe().disposed(by: self.disposeBag)
  }

  @IBAction func clientSend(sender: Any?) {
    let text = self.clientTextField.stringValue

    logClient("Sending msg (\(msgid), \(text))")
    self.client.send(msgid: self.msgid, data: text.data(using: .utf8)!, expectsReply: true)
      .observeOn(MainScheduler.instance)
      .subscribe(onSuccess: { data in
        if let d = data {
          self.logClient("Got reply from server: \(String(data: d, encoding: .utf8)!)")
        } else {
          self.logClient("Got reply from server: nil")
        }
      }, onError: { error in
        self.logClient("Could not send msg: \(error)")
      })
      .disposed(by: self.disposeBag)

    self.msgid += 1
  }

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    self
      .startServer()
      .andThen(self.startClient())
      .subscribe(onCompleted: {
        DispatchQueue.main.async {
          self.logServer("Server started with name: com.qvacua.RxMessagePort.demo.server")
          self.logClient("Connected to com.qvacua.RxMessagePort.demo.server")
        }
      }, onError: { error in
        DispatchQueue.main.async {
          self.logServer("There was an error: \(error)")
          self.logClient("There was an error: \(error)")
        }
      })
      .disposed(by: self.disposeBag)
  }

  func applicationWillTerminate(_ notification: Notification) {
    self.client.stop().subscribe().disposed(by: self.disposeBag)
    self.server.stop().subscribe().disposed(by: self.disposeBag)
  }

  private func startServer() -> Completable {
    logServer("Starting server...")

    self.server.stream
      .observeOn(MainScheduler.instance)
      .subscribe(onNext: { message in
        self.logServer("Got event in stream \(message)")
      })
      .disposed(by: self.disposeBag)

    self.server.syncReplyBody = { (msgid, data) -> Data? in
      DispatchQueue.main.async {
        self.logServer("Preparing synchronous reply to (\(msgid), \(String(describing: data)))")
      }

      if let d = data {
        return "Reply to (\(msgid), \(String(data: d, encoding: .utf8)!))".data(using: .utf8)
      }

      return "Reply to (\(msgid), nil)".data(using: .utf8)
    }

    return self.server.run(as: "com.qvacua.RxMessagePort.demo.server")
  }

  private func startClient() -> Completable {
    self.logClient("Starting client...")
    return self.client.connect(to: "com.qvacua.RxMessagePort.demo.server")
  }

  private func logServer(_ msg: String) {
    self.serverTextView.append(string: "\(msg)\n")
  }

  private func logClient(_ msg: String) {
    self.clientTextView.append(string: "\(msg)\n")
  }
}

extension NSTextView {

  func append(string: String) {
    self.textStorage?.append(NSAttributedString(string: string))
    self.scrollToEndOfDocument(nil)
  }
}
