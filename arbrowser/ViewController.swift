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
    @IBOutlet var webView: WKWebView!
    @IBOutlet var navBar: UINavigationBar!
    @IBOutlet var navIcon: UIBarButtonItem!
    @IBOutlet var pressGesture: UILongPressGestureRecognizer!
    
    var qrRequests = [VNRequest]()
    var anchors = [String:ARAnchor]()
    var urls = [ARAnchor:String]()
    var gradient = CAGradientLayer()
    var detectedDataAnchor: ARAnchor?
    var hitNode = SCNNode()
    var hitUrl = ""
    var processing = false
    var open = false

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
        
        // Set initial webview state
        webView.frame = CGRect(x: 0, y: UIScreen.main.bounds.height, width:view.frame.width, height: UIScreen.main.bounds.height - navBar.frame.maxY)
        webView.loadHTMLString("<body style='background:#fff8'></body>", baseURL: nil)
        let exitControl = UIRefreshControl()
        exitControl.tintColor = .clear
        exitControl.attributedTitle = NSAttributedString(string: "X", attributes: [.foregroundColor: UIColor.red, .font: UIFont.systemFont(ofSize: 30)])
        exitControl.addTarget(self, action: #selector(pullDown(_:)), for: UIControl.Event.valueChanged)
        webView.scrollView.addSubview(exitControl)
        
        // Create QR Detection Request
        let request = VNDetectBarcodesRequest(completionHandler: requestHandler)
        request.symbologies = [.QR]
        qrRequests = [request]
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }

    func requestHandler(request: VNRequest, error: Error?) {
        if let results = request.results as? [VNBarcodeObservation], let frame = self.sceneView.session.currentFrame {
            for result in results {
                if result.confidence == 1, let payload = result.payloadStringValue, payload.starts(with: "http"), anchors[payload] == nil {
                    let rect = result.boundingBox.applying(CGAffineTransform(scaleX: 1, y: -1)).applying(CGAffineTransform(translationX: 0, y: 1))
//                    DispatchQueue.global(qos: .background).async {
//                        if let url = URL(string: payload) {
//                            URLSession.shared.dataTask(with: URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData , timeoutInterval: 60)).resume()
//                        }
//                    }
                    DispatchQueue.main.async {
                        self.navBar.topItem!.title = ""
                        self.pressGesture.isEnabled = true
//                        let url = URL(string:payload)
//                        URLRequest(url: url!)
                        if let hitTestResult = frame.hitTest(CGPoint(x: rect.midX, y: rect.midY), types: [.featurePoint]).first {
//                            if let anchor = self.anchors[payload] {
//                                if results.count<3, let node = self.sceneView.node(for: anchor) {
//                                    let animation = CABasicAnimation(keyPath: "transform")
//                                    animation.fromValue = node.transform
//                                    animation.toValue = SCNMatrix4(hitTestResult.worldTransform)
//                                    animation.duration = 0.5
//                                    node.addAnimation(animation, forKey: nil)
//                                }
//                            } else {
                                // Create an anchor. The node will be created in delegate methods
                                let anchor = ARAnchor(transform: hitTestResult.worldTransform)
                            
                                self.anchors[payload] = anchor
                                self.urls[anchor] = payload
                                self.sceneView.session.add(anchor: anchor)
//                            }
                        }
                    }
                }
            }
        }
        DispatchQueue.main.async {
            self.processing = false
        }
    }
    
    
    // MARK: - ARSCNViewDelegate

    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let shape = SCNBox(width: 0.025, height: 0.025, length: 0.025, chamferRadius: 0.0)
        let node = SCNNode(geometry: shape)
        node.transform = SCNMatrix4(anchor.transform)
        DispatchQueue.global(qos:.background).async {
            if let s = self.urls[anchor], let url = URL(string:"https://www.google.com/s2/favicons?domain=" + s), let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                node.geometry!.firstMaterial?.diffuse.contents = image
            }
        }
//        let url = URL(string: "")
//        let data = try? Data(contentsOf: url!)
//        let Texture = SKTexture(image: UIImage(data: data!)!)
//        let node = SKSpriteNode(texture: Texture)
        return node
    }

    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if self.open, webView.title != "" { DispatchQueue.main.async { self.navBar.topItem!.title = self.webView.title } }
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if self.processing || self.open { return }
                self.processing = true
                // Create a request handler using the captured image from the ARFrame
                let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: frame.capturedImage, options: [:])
                // Process the request
                try imageRequestHandler.perform(self.qrRequests)
            } catch { }
        }
    }
    
    
    // MARK: - ARSessionObserver
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user    
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
    }
    
    @IBAction func openWebView() {
        self.open = true
        CATransaction.setAnimationDuration(1)
        UIView.animate(withDuration: 0.5, animations: {
            self.webView.alpha = 0.9
            self.webView.frame.origin.y = self.navBar.frame.maxY
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
            self.webView.frame.origin.y = self.webView.frame.height
            self.gradient.colors = [UIColor(white: 0, alpha: 0.3).cgColor, UIColor.clear.cgColor, UIColor.clear.cgColor]
        })
        DispatchQueue.main.asyncAfter(deadline: .now()+0.5) { self.webView.loadHTMLString("<body style='background:#fff8'></body>", baseURL: nil) }
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
}
