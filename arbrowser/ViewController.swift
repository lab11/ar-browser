//
//  ViewController.swift
//  arbrowser
//
//  Created by Thomas Zachariah on 2/18/19.
//  Copyright © 2019 Lab11. All rights reserved.
//

import UIKit
import ARKit
import Vision
import WebKit
import SceneKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate, WKNavigationDelegate, UIScrollViewDelegate {
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet var container: UIView!
    @IBOutlet var crossHair: UILabel!
    @IBOutlet var navBar: UIView!
    @IBOutlet var navTitle: UILabel!
    @IBOutlet var navUrl: UILabel!
    @IBOutlet var navAction: UILabel!
    @IBOutlet var navIcon: UIImageView!
    
    var qrRequests = [VNRequest]()
    var requestablePlugins = ["BLECentralPlugin","ChromeSocketsUdp"]
    var gradient = CAGradientLayer(), scrollGradient = CAGradientLayer()
    var hitNode = SCNNode()
    var cdvController: CDVViewController?
    var processing : ARFrame?
    var homeUrl : URL?
    var webView: WKWebView!
    var isOpen = false, canExit = false, canReact = false, canPress = false
    var queue = DispatchQueue(label: Bundle.main.infoDictionary![kCFBundleIdentifierKey as String] as! String + ".visionQueue")
    var slp = SwiftLinkPreview(session: URLSession.shared, workQueue: SwiftLinkPreview.defaultWorkQueue, responseQueue: DispatchQueue.main, cache: InMemoryCache())
    
    
    // MARK: - UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.autoenablesDefaultLighting = true
        
        // Add gradient background for header
        gradient.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 2 * (navBar.frame.height + UIApplication.shared.statusBarFrame.height))
        gradient.colors = [UIColor(white: 0, alpha: 0.3).cgColor, UIColor.clear.cgColor, UIColor.clear.cgColor]
        sceneView.layer.addSublayer(gradient)
        
        // Set initial state of webview
        container.frame = CGRect(x: 0, y: UIScreen.main.bounds.height, width:view.frame.width, height: UIScreen.main.bounds.height - navBar.frame.maxY)
        if let wv = cdvController?.webView as? WKWebView {
            scrollGradient.frame = wv.bounds
            scrollGradient.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
            scrollGradient.locations = [0, 0.02, 0.98, 1]
            wv.configuration.userContentController.addUserScript(makeJS())
            wv.layer.mask = scrollGradient
            wv.scrollView.backgroundColor = .clear
            wv.scrollView.delegate = self
            wv.navigationDelegate = self
            wv.isOpaque = false
            wv.alpha = 0.9
            homeUrl = wv.url
            webView = wv
        }
        
        // Create QR Detection Request
        let request = VNDetectBarcodesRequest(completionHandler: requestHandler)
        request.symbologies = [.QR]
        qrRequests = [request]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Setup AR session
        let configuration = ARWorldTrackingConfiguration()
        if let referenceImages = ARReferenceImage.referenceImages(inGroupNamed: "Devices", bundle: nil) {
            configuration.detectionImages = referenceImages
        }
        sceneView.session.run(configuration, options: [ARSession.RunOptions.resetTracking, ARSession.RunOptions.removeExistingAnchors])
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        // Latch on to the WebView controller
        if segue.identifier == "cordova", let cdvc = segue.destination as? CDVViewController { cdvController = cdvc }
    }
    
    func requestHandler(request: VNRequest, error: Error?) {
        if let results = request.results as? [VNBarcodeObservation] {
            for result in results {
                if result.confidence == 1, let payload = result.payloadStringValue, payload.starts(with: "http"), let frame = self.processing {
                    let rect = result.boundingBox.applying(CGAffineTransform(scaleX: 1, y: -1)).applying(CGAffineTransform(translationX: 0, y: 1))
                    if !canPress { DispatchQueue.main.async { self.navTitle.text = "QR Detected. Loading..." } }
                    DispatchQueue.main.async {
                        if let hitTestResult = frame.hitTest(CGPoint(x: rect.midX, y: rect.midY), types: [.featurePoint]).first {
                            if let node = self.sceneView.scene.rootNode.childNode(withName: payload, recursively: true) {
                                node.transform = SCNMatrix4(node.simdTransform*0.8 + hitTestResult.worldTransform*0.2)
                            } else {
                                // Create an anchor. The node will be created in renderer func
                                let anchor = ARAnchor(name: payload, transform: hitTestResult.worldTransform)
                                self.sceneView.session.add(anchor: anchor)
                            }
                        }
                    }
                }
            }
        }
        DispatchQueue.main.async { self.processing = nil }
    }
    
    func makeJS() -> WKUserScript {
        var js = "";
        var paths = ["www/cordova.js","www/cordova_plugins.js"] // Array of JS paths, starting with Cordova & plugin registry
        let enumerator = FileManager.default.enumerator(atPath: Bundle.main.path(forResource:"www/plugins", ofType:nil) ?? "")
        while let path = enumerator?.nextObject() as? String {
            if path.hasSuffix(".js") { // Plugin files
                paths.append("www/plugins/" + path)
            }
        }
        for path in paths {
            guard let jsFilePath = Bundle.main.path(forResource:path, ofType:nil) else { continue }
            let jsURL = URL.init(fileURLWithPath: jsFilePath)
            try? js.append(contentsOf:String(contentsOfFile: jsURL.path, encoding: String.Encoding.utf8))
        }
        return WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }
    
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        // Create and configure nodes for anchors added to the view's session.
        guard let s = (anchor as? ARImageAnchor)?.referenceImage.name?.replace(" ", with: "/") ?? anchor.name, self.sceneView.scene.rootNode.childNode(withName: s, recursively: true) == nil else { return nil }
        let node = SCNNode(geometry: SCNBox(width: 0.025, height: 0.025, length: 0.025, chamferRadius: 0))
        node.transform = SCNMatrix4(anchor.transform)
        node.geometry!.firstMaterial?.isDoubleSided = true
        node.name = s
        if !canPress {
            canPress = true
            DispatchQueue.main.async { self.navTitle.text = "Touch to Open" }
        }
        DispatchQueue.global(qos:.background).async {
            if let url = URL(string:"https://www.google.com/s2/favicons?domain=" + s), let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                node.geometry!.firstMaterial?.diffuse.contents = image
            }
            self.slp.preview(s, onSuccess: { result in
                if result.icon != nil, let data = try? Data(contentsOf: result.icon!.starts(with:"http") ? URL(string:result.icon!)! : result.finalUrl!.appendingPathComponent(result.icon!)), let image = UIImage(data: data) {
                    node.geometry!.firstMaterial?.diffuse.contents = image
                }
                if let final = result.finalUrl?.absoluteString, let title = result.title {
                    node.setValue(final, forKey: "url")
                    node.setValue(title, forKey: "title")
                }
            }, onError: { error in })
        }
        return node
    }
    
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if isOpen, !canExit, !canReact {
            DispatchQueue.main.async {
                self.navTitle.text = self.webView.title ?? self.webView.url?.absoluteString
                self.navUrl.text = self.webView.title != nil ? self.webView.url?.absoluteString : ""
            }
        }
        if processing != nil || isOpen || hitNode.opacity < 1 { return }
        processing = frame
        queue.async { do { try VNImageRequestHandler(cvPixelBuffer: frame.capturedImage, options: [:]).perform(self.qrRequests) } catch { } }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        if !isOpen { DispatchQueue.main.async {
            self.navTitle.textColor = UIColor(red: 1, green: 0.8, blue: 0, alpha: 1)
            self.navTitle.text = "Scan a QR Code"
            self.navTitle.alpha = 1
        } }
        canPress = false
        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in node.removeFromParentNode() }
        hitNode = SCNNode()
        processing = nil
    }
    
    
    // MARK: - UIScrollViewDelegate
    
    func scrollViewDidScroll(_ sv: UIScrollView) {
        guard isOpen else {return}
        let topOpacity = UIColor(white: 0, alpha: (sv.contentOffset.y <= 0) ? 1 : 0)
        let bottomOpacity = UIColor(white: 0, alpha: (sv.contentOffset.y + sv.frame.size.height >= sv.contentSize.height) ? 1 : 0)
        scrollGradient.colors = [topOpacity.cgColor, UIColor.black.cgColor, UIColor.black.cgColor, bottomOpacity.cgColor]
        webView.layer.mask = scrollGradient
        if sv.contentOffset.y < -64 {
            if !canExit {
                UIImpactFeedbackGenerator(style:.heavy).impactOccurred()
                DispatchQueue.main.async {
                    self.navTitle.text = "❌"
                    for child in self.navBar.subviews { child.alpha = child == self.navTitle ? 1 : 0 }
                }
                canExit = true
            }
        } else if canExit {
            UIImpactFeedbackGenerator(style:.light).impactOccurred()
            canExit = false
        }
        if sv.contentOffset.y < 0, sv.contentOffset.y > -65 {
            let k = 0.6 * (1 + sv.contentOffset.y / 64)
            gradient.colors = [UIColor(white: 0, alpha: 0.3 + k).cgColor, UIColor(white: 0, alpha: k).cgColor, UIColor.clear.cgColor]
            for child in navBar.subviews { child.alpha = k * 5 / 3 }
        }
    }
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if canExit { closeWebView() }
    }
    
    
    // MARK: - User Event Actions
    
    @IBAction func openWebView() {
        self.isOpen = true
        CATransaction.setAnimationDuration(1)
        UIView.animate(withDuration: 0.5, animations: {
            self.webView.alpha = 0.9
            self.container.frame.origin.y = self.navBar.frame.maxY
            self.crossHair.alpha = 0
            self.gradient.colors = [UIColor(white: 0, alpha: 0.9).cgColor, UIColor(white: 0, alpha: 0.6).cgColor, UIColor.clear.cgColor]
        })
    }
    
    @IBAction func closeWebView() {
        CATransaction.setAnimationDuration(1)
        UIView.animate(withDuration: 0.5, animations: {
            self.webView.alpha = 0
            self.container.frame.origin.y = self.webView.frame.height
            self.crossHair.alpha = 0.8
            self.gradient.colors = [UIColor(white: 0, alpha: 0.3).cgColor, UIColor.clear.cgColor, UIColor.clear.cgColor]
        })
        for child in navBar.subviews { child.alpha = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) {
            if let plugins = self.cdvController?.pluginObjects {
                for pluginId in self.requestablePlugins {
                    if let plugin = plugins.object(forKey: pluginId) as? CDVPlugin {
                        plugin.pluginInitialize()
                        plugin.commandDelegate = nil
                    }
                }
            }
            self.webView.loadFileURL(self.homeUrl!, allowingReadAccessTo: self.homeUrl!.deletingPathExtension())
        }
        isOpen = false
        canExit = false
    }
    
    @IBAction func navTap(_ gesture: UILongPressGestureRecognizer) {
        guard isOpen else { return }
        for child in navBar.subviews { child.alpha = 1 }
        if gesture.state == .began || gesture.state == .changed, gesture.location(in: gesture.view).y < 44 {
            canReact = true
            for child in navBar.subviews { child.alpha = child == navTitle ? 1 : 0 }
            navTitle.text = webView.scrollView.contentOffset.y > 0 ? "🔺" : "❌"
            navTitle.alpha = 1
            return
        } else if gesture.state == .ended {
            if navTitle.text == "🔺" { webView.scrollView.setContentOffset(.zero, animated: true) }
            else if navTitle.text == "❌" { closeWebView() }
        }
        canReact = false
    }
    
    @IBAction func sceneTap(_ gesture: UILongPressGestureRecognizer) {
        guard canPress else { return }
        if gesture.state == .began {
            if let result = sceneView.hitTest(gesture.location(in: sceneView), options: [.boundingBoxOnly: true]).first {
                hitNode = result.node
                hitNode.opacity = 0.6
                if let s = hitNode.name, let url = URL(string: s) {
                    if let plugins = self.cdvController?.pluginObjects {
                        for pluginId in self.requestablePlugins {
                            if let plugin = plugins.object(forKey: pluginId) as? CDVPlugin {
                                plugin.commandDelegate = cdvController?.commandDelegate
                            }
                        }
                    }
                    webView.backForwardList.perform(Selector(("_removeAllItems")))
                    webView.load(URLRequest(url: url))
                    navTitle.textColor = .white
                    navTitle.text = hitNode.value(forKey: "title") as? String ?? s
                    navUrl.text = hitNode.value(forKey: "url") as? String ?? ""
                    navIcon.image = hitNode.geometry!.firstMaterial?.diffuse.contents as? UIImage ?? nil
                    for child in navBar.subviews { child.alpha = 1 }
                }
            }
        } else if gesture.state == .changed {
            if let result = sceneView.hitTest(gesture.location(in: sceneView), options: [.boundingBoxOnly: true]).first, result.node == hitNode {
                for child in navBar.subviews { child.alpha = 1 }
                hitNode.opacity = 0.6
            } else {
                for child in navBar.subviews { child.alpha = 0 }
                hitNode.opacity = 1
            }
        } else if gesture.state == .ended {
            if hitNode.opacity < 1 { openWebView() }
            hitNode.opacity = 1
            hitNode = SCNNode()
        }
    }
}
