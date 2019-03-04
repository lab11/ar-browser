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

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet var container: UIView!
    @IBOutlet var navBar: UINavigationBar!
    @IBOutlet var navIcon: UIBarButtonItem!
    @IBOutlet var pressGesture: UILongPressGestureRecognizer!
    @IBOutlet var crossHair: UILabel!
    
    var qrRequests = [VNRequest]()
    var anchors = [String:ARAnchor]()
    var urls = [ARAnchor:String]()
    var gradient = CAGradientLayer()
    var cdvController: CDVViewController?
    var webView: WKWebView!
    var hitNode = SCNNode()
    var hitUrl = ""
    var processing : ARFrame?
    var open = false
    var homeUrl : URL?
    var visionQueue = DispatchQueue(label: Bundle.main.infoDictionary![kCFBundleIdentifierKey as String] as! String + ".serialVisionQueue")

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.autoenablesDefaultLighting = true

        // Add gradient background for header
        gradient.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 2 * (navBar.frame.height + UIApplication.shared.statusBarFrame.height))
        gradient.colors = [UIColor(white: 0, alpha: 0.3).cgColor, UIColor.clear.cgColor, UIColor.clear.cgColor]
        navBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navBar.shadowImage = UIImage()
        sceneView.layer.addSublayer(gradient)
        
        // Set initial state of webview
        container.frame = CGRect(x: 0, y: UIScreen.main.bounds.height, width:view.frame.width, height: UIScreen.main.bounds.height - navBar.frame.maxY)
        if let wv = cdvController?.webView as? WKWebView {
            let exitControl = UIRefreshControl()
            exitControl.tintColor = .clear
            exitControl.attributedTitle = NSAttributedString(string: "X", attributes: [.foregroundColor: UIColor(displayP3Red: 1.0, green: 0.8, blue: 0.0, alpha: 1.0), .font: UIFont.boldSystemFont(ofSize: 30)])
            exitControl.addTarget(self, action: #selector(pullDown(_:)), for: UIControl.Event.valueChanged)
            wv.scrollView.addSubview(exitControl)
            wv.isOpaque = false
            wv.scrollView.backgroundColor = .clear
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
        
        setupARSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "cordova", let cdvc = segue.destination as? CDVViewController {
            cdvController = cdvc
        }
    }
    
    func clearARSession() {
        // Called by sessionInterruptionDidEnd
        DispatchQueue.main.async { self.navBar.topItem!.title = "Scan a QR Code" }
        pressGesture.isEnabled = false
        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in node.removeFromParentNode() }
        anchors = [String:ARAnchor]()
        urls = [ARAnchor:String]()
        hitNode = SCNNode()
        hitUrl = ""
        processing = nil
    }
    
    func setupARSession() {
        let configuration = ARWorldTrackingConfiguration()
        sceneView.session.run(configuration, options: [ARSession.RunOptions.resetTracking, ARSession.RunOptions.removeExistingAnchors])
    }
    
    func requestHandler(request: VNRequest, error: Error?) {
        if let results = request.results as? [VNBarcodeObservation] {
            for result in results {
                if result.confidence == 1, let payload = result.payloadStringValue, payload.starts(with: "http"), let frame = self.processing /*, anchors[payload] == nil*/ {
                    let rect = result.boundingBox.applying(CGAffineTransform(scaleX: 1, y: -1)).applying(CGAffineTransform(translationX: 0, y: 1))
                    
                    if self.pressGesture.isEnabled == false {
                        DispatchQueue.main.async { self.navBar.topItem!.title = "QR Detected. Loading..." }
                    }
                    
//                    DispatchQueue.global(qos: .background).async {
//                        if let url = URL(string: payload) {
//                            URLSession.shared.dataTask(with: URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData , timeoutInterval: 60)).resume()
//                        }
//                    }
                    DispatchQueue.main.async {
//                        let url = URL(string:payload)
//                        URLRequest(url: url!)
                        if let hitTestResult = frame.hitTest(CGPoint(x: rect.midX, y: rect.midY), types: [.featurePoint]).first {
                            if let anchor = self.anchors[payload] {
                                if let node = self.sceneView.node(for: anchor) {
                                    node.transform = SCNMatrix4(node.simdTransform*0.8 + hitTestResult.worldTransform*0.2)
                                }
                            } else {
                                // Create an anchor. The node will be created in delegate methods
                                let anchor = ARAnchor(transform: hitTestResult.worldTransform)
                                self.anchors[payload] = anchor
                                self.urls[anchor] = payload
                                self.sceneView.session.add(anchor: anchor)
                            }
                        }
                    }
                }
            }
        }
        DispatchQueue.main.async {
            self.processing = nil
        }
    }
    
    
    // MARK: - ARSCNViewDelegate

    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let shape = SCNBox(width: 0.025, height: 0.025, length: 0.025, chamferRadius: 0.0)
        let node = SCNNode(geometry: shape)
        node.transform = SCNMatrix4(anchor.transform)
        node.geometry!.firstMaterial?.isDoubleSided = true
        if self.pressGesture.isEnabled == false {
            self.pressGesture.isEnabled = true
            DispatchQueue.main.async { self.navBar.topItem!.title = "" }
        }
        DispatchQueue.global(qos:.background).async {
            if let s = self.urls[anchor], let url = URL(string: (s.starts(with: "https://lab11.github") ? s + "/favicon.png" : "https://www.google.com/s2/favicons?domain=" + s)), let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                node.geometry!.firstMaterial?.diffuse.contents = image
            }
        }
        return node
    }

    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if self.open, webView.title != "" { DispatchQueue.main.async { self.navBar.topItem!.title = self.webView.title } }
        if self.processing != nil || self.open { return }
        self.processing = frame
        visionQueue.async {
            do {
                // Create a request handler using the captured image from the ARFrame
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: frame.capturedImage, options: [:])
                // Process the request
                try imageRequestHandler.perform(self.qrRequests)
            } catch { }
        }
    }
    
    
    // MARK: - ARSessionObserver
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        clearARSession()
    }
    
    @IBAction func openWebView() {
        self.open = true
        CATransaction.setAnimationDuration(1)
        UIView.animate(withDuration: 0.5, animations: {
            self.webView.alpha = 0.9
            self.container.frame.origin.y = self.navBar.frame.maxY
            self.crossHair.alpha = 0.0
            self.gradient.colors = [UIColor(white: 0, alpha: 0.9).cgColor, UIColor(white: 0, alpha: 0.7).cgColor, UIColor.clear.cgColor]
        })
        do {
            self.navIcon = UIBarButtonItem(image: UIImage(data: try Data(contentsOf: URL(string: "http://www.google.com/s2/favicons?domain=" + self.webView.url!.absoluteString)!)), style: .plain, target: self, action: nil)
        } catch {
        }
    }
    
    @IBAction func closeWebView() {
        guard self.webView.alpha > 0 else { return }
        CATransaction.setAnimationDuration(1)
        UIView.animate(withDuration: 0.5, animations: {
            self.webView.alpha = 0.0
            self.container.frame.origin.y = self.webView.frame.height
            self.crossHair.alpha = 0.8
            self.gradient.colors = [UIColor(white: 0, alpha: 0.3).cgColor, UIColor.clear.cgColor, UIColor.clear.cgColor]
        })
        
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) { self.webView.loadFileURL(self.homeUrl!, allowingReadAccessTo: self.homeUrl!.deletingPathExtension()) }
        self.navBar.topItem!.title = ""
        self.open = false
    }
    
    @IBAction func pullDown(_ sender: UIRefreshControl) {
        closeWebView()
        sender.endRefreshing()
    }
    
    @IBAction func sceneTap(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            if let result = sceneView.hitTest(gesture.location(in: sceneView), options: [.boundingBoxOnly: true]).first {
                hitNode = result.node
                hitNode.opacity = 0.6
                if let anchor = sceneView.anchor(for: hitNode), let s = urls[anchor], let url = URL(string: s) {
                    hitUrl = s
                    webView.backForwardList.perform(Selector(("_removeAllItems")))
                    webView.load(URLRequest(url: url))
                    navBar.topItem!.title = hitUrl
                }
            }
        } else if gesture.state == .changed {
            if let result = sceneView.hitTest(gesture.location(in: sceneView), options: [.boundingBoxOnly: true]).first, result.node == hitNode {
                navBar.topItem!.title = hitUrl
                hitNode.opacity = 0.6
            } else {
                navBar.topItem!.title = ""
                hitNode.opacity = 1
            }
        } else if gesture.state == .ended {
            if hitNode.opacity < 1 {
                openWebView()
            } else {
                navBar.topItem!.title = ""
            }
            hitNode.opacity = 1
        }
    }
    
    @IBAction func scenePinch(_ gesture : UIPinchGestureRecognizer) {
        guard pressGesture.isEnabled == true else { return }
        if gesture.scale < 0.25 {
            clearARSession()
        }
    }
}
