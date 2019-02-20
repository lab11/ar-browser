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
    @IBOutlet var tapLabel: UILabel!
    
    var qrRequests = [VNRequest]()
    var anchors = [String:ARAnchor]()
    var arlabels = [ARAnchor:String]()
    var gradient = CAGradientLayer()
    var detectedDataAnchor: ARAnchor?
    var processing = false
    var open = false

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self

        // Add gradient background for header
        gradient.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: 2 * (navBar.frame.height + UIApplication.shared.statusBarFrame.height))
        gradient.colors = [UIColor(white: 0, alpha: 0.3).cgColor, UIColor.clear.cgColor, UIColor.clear.cgColor]
        navBar.setBackgroundImage(UIImage(), for: UIBarMetrics.default)
        navBar.shadowImage = UIImage()
        sceneView.layer.addSublayer(gradient)
        
        // Set initial webview state
        webView.frame = CGRect(x: 0, y: UIScreen.main.bounds.height, width:view.frame.width, height: UIScreen.main.bounds.height - navBar.frame.maxY)
        webView.loadHTMLString("<body style='background:#fff3'></body>", baseURL: nil)
        webView.backgroundColor = .clear
        webView.isOpaque = false
        let exitControl = UIRefreshControl()
        exitControl.tintColor = .clear
        exitControl.attributedTitle = NSAttributedString(string: "X", attributes: [.foregroundColor: UIColor.red, .font: UIFont.systemFont(ofSize: 30)])
        exitControl.addTarget(self, action: #selector(exitWebView(_:)), for: UIControl.Event.valueChanged)
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
        if let results = request.results, let result = results.first as? VNBarcodeObservation, let payload = result.payloadStringValue, payload.starts(with: "http") {
            // Get the bounding box for the bar code and find the center
            var rect = result.boundingBox
            // Flip coordinates
            rect = rect.applying(CGAffineTransform(scaleX: 1, y: -1))
            rect = rect.applying(CGAffineTransform(translationX: 0, y: 1))
            // Get center
//            let center = CGPoint(x: rect.midX, y: rect.midY)
            
//            let url = URL(string:payload)
//            let req = URLRequest(url: url!)
            
            DispatchQueue.main.async {
                
//                let webView = CDVViewController()
//                webView.view.frame = CGRect(x: 0, y: self.view.frame.height/2, width: self.view.frame.width, height: self.view.frame.height/2)
//                self.view.addSubview(webView.view)
//                NSLog(payload)
                if !self.open {
                    self.webView.loadHTMLString("<html><body style='background:#fff8'></body></html>", baseURL: nil)
                    self.navBar.topItem!.title = payload
                    self.tapLabel.alpha = 0.8
                    let url = URL(string:payload)
                    let req = URLRequest(url: url!)
                    self.webView.load(req)
                }
                
//                if !self.view.subviews.contains(self.webView) {
//                self.view.addSubview(self.webView!)
//                self.webView.alpha = 0.9
//                }
                
//                if let hitTestResults = self.sceneView?.hitTest(center, types: [.featurePoint] ),
//                    let hitTestResult = hitTestResults.first {
//                    if let detectedDataAnchor = self.detectedDataAnchor,
//                        let node = self.sceneView.node(for: detectedDataAnchor) {
//                        node.transform = SCNMatrix4(hitTestResult.worldTransform)
//                    } else {
//                        // Create an anchor. The node will be created in delegate methods
//                        self.detectedDataAnchor = ARAnchor(transform: hitTestResult.worldTransform)
//                        self.sceneView.session.add(anchor: self.detectedDataAnchor!)
//                    }
//                }
                self.processing = false
            }
        } else {
            self.processing = false
        }
//        if let results = request.results as? [VNBarcodeObservation] {
//            for result in results {
//                DispatchQueue.main.async {
//                    NSLog("%@", result)
//                    if let hitTestResults = self.sceneView?.hitTest(CGPoint(x: result.boundingBox.midX, y: result.boundingBox.midY), types: [.featurePoint] ), let hitTestResult = hitTestResults.first {
//                        // Place an anchor
//                        let anchor = ARAnchor(transform: hitTestResult.worldTransform)
//                        self.anchors[result.payloadStringValue!] = anchor
//                        self.arlabels[anchor] = result.payloadStringValue
//                        self.sceneView.session.add(anchor: anchor)
//                        //TODO: change to width and height
////                        let plane = SCNPlane(width: result.boundingBox.width, height: result.boundingBox.height)
////                        let material = SCNMaterial()
////                        material.diffuse.contents = UIColor.red
////                        plane.materials = [material]
////
////                        let node = SCNNode()
////                        node.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
////
////                        node.position = SCNVector3(hitTestResult.worldTransform.columns.3.x,
////                                                   hitTestResult.worldTransform.columns.3.y,
////                                                   hitTestResult.worldTransform.columns.3.z)
////
////                        node.geometry = plane
////                        self.sceneView.scene.rootNode.addChildNode(node)
//                    }
//                }
//            }
//            DispatchQueue.main.async {
//                self.processing = false
//            }
//        } else {
//            self.processing = false
//        }
    }
    
    
    // MARK: - ARSCNViewDelegate

    // Override to create and configure nodes for anchors added to the view's session.
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {

//        if self.detectedDataAnchor?.identifier == anchor.identifier {
            let sphere = SCNSphere(radius: 1.0)
            sphere.firstMaterial?.diffuse.contents = UIColor.red
            let sphereNode = SCNNode(geometry: sphere)
            sphereNode.transform = SCNMatrix4(anchor.transform)
            return sphereNode
//        }
        
        
        //TODO: change to width and height
//        let plane = SCNPlane(width: 0.1, height: 0.1)
//        let material = SCNMaterial()
//        material.diffuse.contents = UIColor.red
//        plane.materials = [material]
        
//        let node = SCNNode()
//        node.simdTransform = anchor.transform;
//        node.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
//
//        node.position = SCNVector3(anchor.transform.columns.3.x,
//                                   anchor.transform.columns.3.y,
//                                   anchor.transform.columns.3.z)

//        node.geometry = plane
//        node.geometry = SCNBox(width: 0.1,height: 0.1,length: 0.1,chamferRadius: 0.1)
//        node.geometry = SCNText(string: arlabels[anchor], extrusionDepth: 1)
        
//        return node
    }

    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                DispatchQueue.main.async { if self.open { self.navBar.topItem!.title = self.webView.title } }
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
    
    @IBAction func exitWebView(_ sender: UIRefreshControl) {
        UIView.animate(withDuration: 0.5, animations: {
            self.webView.alpha = 0.0
            self.webView.frame.origin.y = self.webView.frame.height
            self.gradient.colors = [UIColor(white: 0, alpha: 0.3).cgColor, UIColor.clear.cgColor, UIColor.clear.cgColor]
        })
        self.navBar.topItem!.title = self.webView.url!.absoluteString
        self.open = false
        sender.endRefreshing()
    }
    
    @IBAction func navTap() {
        CATransaction.setAnimationDuration(1)
        if self.webView.alpha == 0 {
            guard let ti = self.navBar.topItem, let title = ti.title, title.starts(with:"http") else {return}
            self.open = true
            UIView.animate(withDuration: 0.5, animations: {
                self.webView.alpha = 0.9
                self.webView.frame.origin.y = self.navBar.frame.maxY
                self.gradient.colors = [UIColor(white: 0, alpha: 0.9).cgColor, UIColor(white: 0, alpha: 0.7).cgColor, UIColor.clear.cgColor]
            })
            do {
                self.navIcon = UIBarButtonItem(image: UIImage(data: try Data(contentsOf: URL(string: "http://www.google.com/s2/favicons?domain=" + self.webView.url!.absoluteString)!)), style: .plain, target: self, action: nil)
            } catch {
            }
        } else {
            exitWebView(_:UIRefreshControl())
        }
    }
}
