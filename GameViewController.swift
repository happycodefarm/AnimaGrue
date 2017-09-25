//
//  GameViewController.swift
//  AnimaGrue
//
//  Created by guillaume on 05/09/2017.
//  Copyright © 2017 Guillaume Stagnaro. All rights reserved.


import UIKit
import SpriteKit
import GameplayKit
import CoreMotion
import CoreLocation

//let IP = "192.168.1.3"
let DEFAULT_IP = "192.168.1.4" // imac
let DEFAULT_PORT = 8080

class GameViewController: UIViewController {
    
    @IBOutlet weak var speedSlider: UISlider!
    @IBOutlet weak var resetButton: UIButton!
 
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
            
            speedSlider.addTarget(scene, action: #selector(scene.speedChanged(sender:)), for: .valueChanged)
            resetButton.addTarget(scene, action: #selector(scene.reset(sender:)), for: .touchDown)
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
    
    var client:OSCClient!
    
    private var mouseNode : SKShapeNode?
    private var logNode : SKLabelNode?
    
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
        
        mouseNode = SKShapeNode(rectOf: CGSize(width: self.size.width * 0.2, height: self.size.width * 0.15) )
        logNode = SKLabelNode(text: "Log")
       
        mouseNode?.fillColor = .blue
        mouseNode?.lineWidth = 0
        mouseNode?.glowWidth = 0.0
        
        self.backgroundColor = .darkGray
        self.addChild(mouseNode!)
        self.addChild(logNode!)
        
        mouseNode?.position = CGPoint(x: self.size.width/2, y: self.size.height/2)
        logNode?.position = CGPoint(x: self.size.width/2, y: self.size.height/2)
        
        motionManager = CMMotionManager()
        
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.1
            motionManager.startDeviceMotionUpdates(to: OperationQueue.main) {
                (data, error) in
                if let data = data {
                    
                    let message = OSCMessage(
                        OSCAddressPattern("/att"),
                       
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
       // locationManager.startUpdatingHeading()
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        
        if keyPath == "savedPort" || keyPath == "savedIP" {
            print("updating key\(keyPath ?? "bug ?")")
            updateFromDefaults()
            client.address = ip
            client.port = port
        }
    }
    
    func registerSettingsBundle(){
        //let appDefaults =
        
        UserDefaults.standard.register(defaults: [String:AnyObject]())
        UserDefaults.standard.synchronize()
        //NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    func updateFromDefaults(){
        
        //Get the defaults
        let defaults = UserDefaults.standard
        
        //Set the controls to the default values.
       
        if let savedIP = defaults.string(forKey: "savedIP"){
            ip = savedIP
            print("asved ip ok \(ip)")
        } else{
            print("asved ip error")
        }
        
        port = defaults.integer(forKey: "savedPort")
        print("port is \(port)")
    }
    
   @objc func defaultsChanged(){
        print("default changed")
        updateFromDefaults()
    }
    
//    @IBAction func updateDefaults(sender: AnyObject) {
//        updateFromDefaults()
//    }
    
    @objc func speedChanged(sender: UISlider) {
        let message = OSCMessage(
            OSCAddressPattern("/speed"),
            sender.value
        )
        self.client.send(message)
    }
    
    @objc func reset(sender: UIButton) {
                
        let message = OSCMessage(
            OSCAddressPattern("/reset")
        )
        self.client.send(message)
    }
}

