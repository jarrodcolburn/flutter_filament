import Flutter
import UIKit
import OpenGLES.ES3
import GLKit


public class SwiftPolyvoxFilamentPlugin: NSObject, FlutterPlugin, FlutterTexture {
  
    var registrar : FlutterPluginRegistrar
    var textureId: Int64?
    var registry: FlutterTextureRegistry

    var width: Double = 0
    var height: Double = 0
  
    var context: EAGLContext?;
    var targetPixelBuffer: CVPixelBuffer?;
    var textureCache: CVOpenGLESTextureCache?;
    var texture: CVOpenGLESTexture? = nil;
    var frameBuffer: GLuint = 0;

    
    var pixelBufferAttrs = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_32BGRA),
        kCVPixelBufferOpenGLCompatibilityKey: kCFBooleanTrue,
        kCVPixelBufferOpenGLESCompatibilityKey: kCFBooleanTrue,
        kCVPixelBufferIOSurfacePropertiesKey: [:]
    ] as CFDictionary

    var resources:NSMutableDictionary = [:]
    var viewer:UnsafeMutableRawPointer? = nil
  
    var displayLink:CADisplayLink? = nil
    
    static var messenger : FlutterBinaryMessenger? = nil;
  
    var loadResourcePtr: UnsafeMutableRawPointer? = nil
    var freeResourcePtr: UnsafeMutableRawPointer? = nil
    var resourcesPtr : UnsafeMutableRawPointer? = nil
  
    var loadResource : @convention(c) (UnsafeRawPointer, UnsafeMutableRawPointer) -> ResourceBuffer = { uri, resourcesPtr in
      print("Loading resource buffer")
      
      let instance:SwiftPolyvoxFilamentPlugin = Unmanaged<SwiftPolyvoxFilamentPlugin>.fromOpaque(resourcesPtr).takeUnretainedValue()

      let uriString = String(cString:uri.assumingMemoryBound(to: UInt8.self))
      
      let key = instance.registrar.lookupKey(forAsset:uriString)

      let path = Bundle.main.path(forResource: key, ofType:nil)
      do {
        let foo: String = path!
        let data = try Data(contentsOf: URL(fileURLWithPath:foo))
        let resId = instance.resources.count
        let nsData = data as NSData
        instance.resources[resId] = nsData
        let rawPtr = nsData.bytes
        return ResourceBuffer(data:rawPtr, size:UInt32(nsData.count), id:UInt32(resId))
      } catch {
          print("Error opening file: \(error)")
          return ResourceBuffer()
      }
        return ResourceBuffer()
    }
  
    var freeResource : @convention(c) (UInt32,UnsafeMutableRawPointer) -> () = { rid, resourcesPtr in
      let instance:SwiftPolyvoxFilamentPlugin = Unmanaged<SwiftPolyvoxFilamentPlugin>.fromOpaque(resourcesPtr).takeUnretainedValue()
      instance.resources.removeObject(forKey:rid)
    }
  
    func createDisplayLink() {
      displayLink = CADisplayLink(target: self,
                                      selector: #selector(doRender))
      
      displayLink!.add(to: .current, forMode:  RunLoop.Mode.default)
  }
  
    @objc func doRender() {
      if(viewer != nil) {
        render(viewer)
        self.registry.textureFrameAvailable(self.textureId!)
      }
    }
  
    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        if(targetPixelBuffer == nil) {
            print("empty")
            return nil;
        } 
        return Unmanaged.passRetained(targetPixelBuffer!);
    }


    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let _messenger = registrar.messenger();
        messenger = _messenger;
        let channel = FlutterMethodChannel(name: "app.polyvox.filament/event", binaryMessenger: _messenger)
      let instance = SwiftPolyvoxFilamentPlugin(textureRegistry: registrar.textures(), registrar:registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
  
    init(textureRegistry: FlutterTextureRegistry, registrar:FlutterPluginRegistrar) {
        self.registry = textureRegistry;
        self.registrar = registrar
    }
  
    private func createPixelBuffer(width:Int, height:Int) {
      
      if(targetPixelBuffer != nil) {
        destroy_swap_chain(self.viewer)
      }
      if(CVPixelBufferCreate(kCFAllocatorDefault, Int(width), Int(height),
                                      kCVPixelFormatType_32BGRA, pixelBufferAttrs, &targetPixelBuffer) != kCVReturnSuccess) {
        print("Error allocating pixel buffer")
      }
      if(self.viewer != nil) {
        create_swap_chain(self.viewer,         unsafeBitCast(targetPixelBuffer!, to: UnsafeMutableRawPointer.self))
        update_viewport_and_camera_projection(self.viewer!, Int32(width), Int32(height), 1.0);
      }

      print("Pixel buffer created")
    }
  
    private func initialize(width:Int32, height:Int32) {

      createPixelBuffer(width:Int(width), height:Int(height))
      self.textureId = self.registry.register(self)

      loadResourcePtr = unsafeBitCast(loadResource, to: UnsafeMutableRawPointer.self)
      freeResourcePtr = unsafeBitCast(freeResource, to: UnsafeMutableRawPointer.self)

      viewer = filament_viewer_new_ios(
        unsafeBitCast(targetPixelBuffer!, to: UnsafeMutableRawPointer.self),
        loadResourcePtr!,
        freeResourcePtr!,
        Unmanaged.passUnretained(self).toOpaque()
      )

      update_viewport_and_camera_projection(self.viewer!, Int32(width), Int32(height), 1.0);
      
      createDisplayLink()

    }
  
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
      let methodName = call.method;

      switch methodName {
        case "initialize":
            let args = call.arguments as! Array<Int32>
            initialize(width:args[0], height:args[1])
            result(self.textureId);
        case "setBackgroundImage":
            let uri = call.arguments as! String
            set_background_image(self.viewer!, uri)
            render(self.viewer!)
            self.registry.textureFrameAvailable(self.textureId!)
            result("OK")
        case "resize":
            let args = call.arguments as! Array<Double>
            let width = Int(args[0])
            let height = Int(args[1])
            createPixelBuffer(width: width, height:height)
            result("OK")
        case "loadSkybox":
            load_skybox(self.viewer!, call.arguments as! String)
            result("OK");
        case "removeSkybox":
            remove_skybox(self.viewer!)
            result("OK");
        case "loadGlb":
            let assetPtr = load_glb(self.viewer, call.arguments as! String)
            result(unsafeBitCast(assetPtr, to:Int64.self));
        case "loadGltf":
          let args = call.arguments as! Array<Any?>
          result(load_gltf(self.viewer, args[0] as! String, args[1] as! String));
        case "removeAsset":
          let assetPtr = UnsafeMutableRawPointer.init(bitPattern: call.arguments as! Int)
          remove_asset(viewer!, assetPtr)
          result("OK")
        case "clearAssets":
          clear_assets(viewer!)
          result("OK")
        case "loadIbl":
          load_ibl(self.viewer, call.arguments as! String)
          result("OK");
        case "removeIbl":
          remove_ibl(self.viewer)
          result("OK");
      case "setCamera":
        let args = call.arguments as! Array<Any?>
        let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
        set_camera(self.viewer, assetPtr, args[1] as! String)
        result("OK");
      case "playAnimation":
        let args = call.arguments as! Array<Any?>
        let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
        let animationIndex = args[1] as! Int32;
        let loop = args[2] as! Bool;
        play_animation(assetPtr, animationIndex, loop)
        result("OK");
      case "stopAnimation":
        let args = call.arguments as! Array<Any?>
        let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
        let animationIndex = args[1] as! Int32
        stop_animation(assetPtr, animationIndex) // TODO
        result("OK");
      case "getTargetNames":
        let args = call.arguments as! Array<Any?>
        let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
        let meshName = args[1] as! String
        let numNames = get_target_name_count(assetPtr, meshName)
        var names = [String]()
        for i in 0...numNames - 1{
          let outPtr = UnsafeMutablePointer<CChar>.allocate(capacity:256)
          get_target_name(assetPtr, meshName, outPtr, i)
          names.append(String(cString:outPtr))
        }
        result(names);
      case "getAnimationNames":
        let assetPtr = UnsafeMutableRawPointer.init(bitPattern: call.arguments as! Int)
        let numNames = get_animation_count(assetPtr)
        var names = [String]()
        for i in 0...numNames - 1{
          let outPtr = UnsafeMutablePointer<CChar>.allocate(capacity:256)
          get_animation_name(assetPtr, outPtr, i)
          names.append(String(cString:outPtr))
        }
        result(names);
      case "applyWeights":
        let args = call.arguments as! Array<Any?>
        let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
        let weights = args[1] as! Array<Double>
        weights.map { Float($0) }.withUnsafeBufferPointer {
          apply_weights(assetPtr,           UnsafeMutablePointer<Float>.init(mutating:$0.baseAddress), Int32(weights.count))

        }
        result("OK")
      case "zoom":
        let args = call.arguments as! Array<Any?>
        let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
        let factor = args[1] as! Double
        scroll(assetPtr, 0,0, Float(factor))
        result("OK")
      case "animateWeights":
        let args = call.arguments as! Array<Any?>
        let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
        let frameData = args[1] as! Array<Double>
        let numWeights = args[2] as! Int
        let numFrames = args[3] as! Int
        let frameLenInMs = args[4] as! Double
        frameData.map { Float($0)}.withUnsafeBufferPointer {
          animate_weights(assetPtr, UnsafeMutablePointer<Float>.init(mutating:$0.baseAddress), Int32(numWeights), Int32(numFrames), Float(frameLenInMs))
        }
        result("OK")
      case "panStart":
        let args = call.arguments as! Array<Any>
        grab_begin(self.viewer, args[0] as! Int32, args[1] as! Int32, true)
        result("OK")
      case "panUpdate":
        let args = call.arguments as! Array<Any>
        grab_update(self.viewer, args[0] as! Int32, args[1] as! Int32)
        result("OK")
      case "panEnd":
        grab_end(self.viewer)
        result("OK")
      case "rotateStart":
        let args = call.arguments as! Array<Any>
        grab_begin(self.viewer, args[0] as! Int32, args[1] as! Int32, false)
        result("OK")
      case "rotateUpdate":
        let args = call.arguments as! Array<Any>
        grab_update(self.viewer, args[0] as! Int32, args[1] as! Int32)
        result("OK")
      case "rotateEnd":
        grab_end(self.viewer)
        result("OK")
      case "setPosition":
        let args = call.arguments as! Array<Any>
        let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
        let x = Float(args[1] as! Double)
        set_position(assetPtr, x, Float(args[2] as! Double), Float(args[3] as! Double))
        result("OK")
      case "setRotation":
        let args = call.arguments as! Array<Any>
        let assetPtr = UnsafeMutableRawPointer.init(bitPattern: args[0] as! Int)
        set_rotation(assetPtr, Float(args[1] as! Double), Float(args[2] as! Double), Float(args[3] as! Double), Float(args[4] as! Double))
        result("OK")
      default:
        result(FlutterMethodNotImplemented)
      }
    }
}

