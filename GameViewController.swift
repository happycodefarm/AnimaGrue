//
//  GameViewController.swift
//  AnimaGrue
//
//  Created by guillaume on 05/09/2017.
//  Copyright © 2017 Guillaume Stagnaro. All rights reserved.


import UIKit
import SpriteKit
//import GameplayKit
import CoreMotion
import CoreLocation

//let IP = "192.168.1.3"
let DEFAULT_IP = "192.168.1.4" // imac
let DEFAULT_PORT = 8080
let DEFAULT_PATH = "grue/"

class GameViewController: UIViewController {
    
    @IBOutlet weak var chaseButton: UIButton!
    @IBOutlet weak var freeButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let view = self.view as! SKView? {
      
            let scene = GrueScene(size: view.frame.size)
            
            // Set the scale mode to scale to fit the window
            scene.scaleMode = .aspectFill
            scene.name = "grueScene"
            
            // Present the scene
            view.presentScene(scene)
            
            view.ignoresSiblingOrder = true
            view.showsFPS = false
            view.showsNodeCount = false
            
            view.ignoresSiblingOrder = true
            
            view.showsFPS = false
            view.showsNodeCount = false
            
            chaseButton.addTarget(scene, action: #selector(scene.chase(sender:)), for: .touchDown)
            freeButton.addTarget(scene, action: #selector(scene.free(sender:)), for: .touchDown)
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
}

class GrueScene: SKScene, CLLocationManagerDelegate {
    var motionManager: CMMotionManager!
    var locationManager:CLLocationManager!
    
    var ip = DEFAULT_IP
    var port = DEFAULT_PORT
    var oscPath = DEFAULT_PATH
    var flightSpeed:CGFloat = 0.0
    
    var client:OSCClient!
    
    private var mouseNode : SKShapeNode?
    private var logNode : SKLabelNode?
    private var speedNode : SKShapeNode?
    
    override func didMove(to view: SKView) {
       
        registerSettingsBundle()
        updateFromDefaults()
        
        client = OSCClient(address: ip, port: port)
        
        UserDefaults.standard.addObserver(self,
                                         forKeyPath: "savedPort",
                                         options: [.new, .old, .initial, .prior],
                                         context: nil)

        UserDefaults.standard.addObserver(self,
                                          forKeyPath: "savedIP",
                                          options: [.new, .old, .initial, .prior],
                                          context: nil)
        
        UserDefaults.standard.addObserver(self,
                                          forKeyPath: "savedPath",
                                          options: [.new, .old, .initial, .prior],
                                          context: nil)
        
        speedNode = SKShapeNode(rect: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
        speedNode?.fillColor = #colorLiteral(red: 0.4509804249, green: 0.4509804249, blue: 0.4509804249, alpha: 1)
        speedNode?.yScale = 1 - flightSpeed / 50.0
        speedNode?.strokeColor = .clear
        self.addChild(speedNode!)
        
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: self.size.width * 0.3))
        path.addLine(to: CGPoint(x: self.size.width * 0.2, y: -self.size.width * 0.15))
        path.addLine(to: CGPoint(x: 0, y: -self.size.width * 0.1))
        path.addLine(to: CGPoint(x: -self.size.width * 0.2, y: -self.size.width * 0.15))
        path.addLine(to: CGPoint(x: 0, y: self.size.width * 0.3))
        
        mouseNode = SKShapeNode(path: path)
        mouseNode?.fillColor = #colorLiteral(red: 0.5882353187, green: 0.5882353187, blue: 0.5882353187, alpha: 1)
        mouseNode?.strokeColor = .clear
        
        logNode = SKLabelNode(text: "Log")
        logNode?.fontSize = 20
        self.backgroundColor = #colorLiteral(red: 0.3215686381, green: 0.3215686381, blue: 0.3215686381, alpha: 1)
        self.addChild(mouseNode!)
        self.addChild(logNode!)
        
        mouseNode?.position = CGPoint(x: self.size.width/2, y: self.size.height/2)
        logNode?.position = CGPoint(x: self.size.width/2, y: 50)
        
        logNode?.text = "\(ip):\(port)"
        
        motionManager = CMMotionManager()
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: OperationQueue.main) {
                (data, error) in
                if let data = data {
                    
                    let message = OSCMessage(
                        OSCAddressPattern("\(self.oscPath)/att"),
                       
                        data.attitude.roll * 180.0 / .pi,
                        data.attitude.pitch * 180.0 / .pi,
                        data.attitude.yaw * 180.0 / .pi
                    )
                    self.client.send(message)
                    self.mouseNode?.zRotation = CGFloat(-data.attitude.yaw)
                }
            }
        }
        
        locationManager  = CLLocationManager()
        locationManager.delegate = self
        
        locationManager.requestWhenInUseAuthorization()
        
        let panSeedGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanSpeed(_:)))
        panSeedGesture.minimumNumberOfTouches = 1
        panSeedGesture.maximumNumberOfTouches = 1
        self.view?.addGestureRecognizer(panSeedGesture)
    }
    
    @objc
    func handlePanSpeed(_ gestureRecognize: UIPanGestureRecognizer) {
       
        let value = gestureRecognize.translation(in: self.view).y/5.0
        gestureRecognize.setTranslation(CGPoint.zero, in: self.view)
        
        flightSpeed += value
        flightSpeed = min(max(0,flightSpeed),50)
        
         speedNode?.yScale = 1 - flightSpeed / 50.0
        
        let message = OSCMessage(
            OSCAddressPattern("\(self.oscPath)/speed"),
            Double(flightSpeed)
        )
        self.client.send(message)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == "savedPort" || keyPath == "savedIP" || keyPath == "savedPath" {
            print("updating key \(keyPath ?? "bug ?")")
            updateFromDefaults()
            client.address = ip
            client.port = port
        }
    }
    
    func registerSettingsBundle(){
        UserDefaults.standard.register(defaults: ["savedPort":DEFAULT_PORT, "savedIP":DEFAULT_IP, "savedPath":DEFAULT_PATH])
        //UserDefaults.standard.register(defaults: [String:AnyObject]())
        UserDefaults.standard.synchronize()
    }
    
    func updateFromDefaults(){
        
        //Get the defaults
        let defaults = UserDefaults.standard
        
        //Set the controls to the default values.
       
        if let savedIP = defaults.string(forKey: "savedIP"){
            ip = savedIP
            print("saved ip ok \(ip)")
        } else{
            print("saved ip error")
        }
        
        if let savedPath = defaults.string(forKey: "savedPath") {
            oscPath = savedPath
             print("saved path ok \(oscPath)")
        } else {
             print("saved path error")
        }
        
        port = defaults.integer(forKey: "savedPort")
        print("port is \(port)")
        
         logNode?.text = "\(ip):\(port)"
    }
    
   @objc func defaultsChanged(){
        print("default changed")
        updateFromDefaults()
    }
    
    @objc func chase(sender: UIButton) {
                
        let message = OSCMessage(
            OSCAddressPattern("\(self.oscPath)/chase")
        )
        self.client.send(message)
    }
    
    @objc func free(sender: UIButton) {
        
        let message = OSCMessage(
            OSCAddressPattern("\(self.oscPath)/free")
        )
        self.client.send(message)
    }
}

