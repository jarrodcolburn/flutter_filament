import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:js_interop';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/filament_controller.dart';
import 'package:ffi/ffi.dart';
import 'package:flutter_filament/animations/animation_data.dart';
import 'package:flutter_filament/generated_bindings.dart';
import 'package:flutter_filament/rendering_surface.dart';

class _Allocator implements Allocator {
  const _Allocator();
  @override
  Pointer<T> allocate<T extends NativeType>(int byteCount, {int? alignment}) {
    return Pointer<T>.fromAddress(flutter_filament_web_allocate(byteCount));
  }

  @override
  void free(Pointer<NativeType> pointer) {
    // TODO: implement free
  }
}

final allocator = _Allocator();

// ignore: constant_identifier_names
const FilamentEntity _FILAMENT_ASSET_ERROR = 0;

class FilamentControllerFFI extends FilamentController {
  final _channel = const MethodChannel("app.polyvox.filament/event");

  bool _usesBackingWindow = false;
  @override
  bool get requiresTextureWidget => !_usesBackingWindow;

  double _pixelRatio = 1.0;

  // ignore: prefer_final_fields
  Pointer<Void> _assetManager = nullptr;
  // ignore: prefer_final_fields
  Pointer<Void> _viewer = nullptr;
  // ignore: prefer_final_fields
  Pointer<Void> _driver = nullptr.cast<Void>();

  final String? uberArchivePath;

  @override
  final rect = ValueNotifier<Rect?>(null);

  @override
  Stream<FilamentEntity> get pickResult => _pickResultController.stream;
  final _pickResultController = StreamController<FilamentEntity>.broadcast();

  int? _resizingWidth;
  int? _resizingHeight;

  Timer? _resizeTimer;

  ///
  /// This controller uses platform channels to bridge Dart with the C/C++ code for the Filament API.
  /// Setting up the context/texture (since this is platform-specific) and the render ticker are platform-specific; all other methods are passed through by the platform channel to the methods specified in FlutterFilamentApi.h.
  ///
  FilamentControllerFFI({this.uberArchivePath}) {
    // on some platforms, we ignore the resize event raised by the Flutter RenderObserver
    // in favour of a window-level event passed via the method channel.
    // (this is because there is no apparent way to exactly synchronize resizing a Flutter widget and resizing a pixel buffer, so we need
    // to handle the latter first and rebuild the swapchain appropriately).
    _channel.setMethodCallHandler((call) async {
      if (call.arguments[0] == _resizingWidth &&
          call.arguments[1] == _resizingHeight) {
        return;
      }
      _resizeTimer?.cancel();
      _resizingWidth = call.arguments[0];
      _resizingHeight = call.arguments[1];
      _resizeTimer = Timer(const Duration(milliseconds: 500), () async {
        this.rect.value = Offset.zero &
            ui.Size(_resizingWidth!.toDouble(), _resizingHeight!.toDouble());
        await resize();
      });
    });

    if (!kIsWeb) {
      if (Platform.isIOS || Platform.isMacOS || Platform.isWindows) {
        DynamicLibrary.process();
      } else {
        DynamicLibrary.open("libflutter_filament_android.so");
      }
      if (Platform.isWindows) {
        _channel.invokeMethod("usesBackingWindow").then((result) {
          _usesBackingWindow = result;
        });
      }
    }
  }

  bool _rendering = false;
  @override
  bool get rendering => _rendering;

  @override
  Future<FilamentEntity> addLight(
      int type,
      double colour,
      double intensity,
      double posX,
      double posY,
      double posZ,
      double dirX,
      double dirY,
      double dirZ,
      bool castShadows) {
    // TODO: implement addLight
    throw UnimplementedError();
  }

  @override
  Future clearAssets() {
    // TODO: implement clearAssets
    throw UnimplementedError();
  }

  @override
  Future clearBackgroundImage() {
    // TODO: implement clearBackgroundImage
    throw UnimplementedError();
  }

  @override
  Future clearLights() {
    // TODO: implement clearLights
    throw UnimplementedError();
  }

  @override
  Future destroy() {
    // TODO: implement destroy
    throw UnimplementedError();
  }

  @override
  Future destroyTexture() {
    // TODO: implement destroyTexture
    throw UnimplementedError();
  }

  @override
  Future destroyViewer() {
    // TODO: implement destroyViewer
    throw UnimplementedError();
  }

  @override
  Future<double> getAnimationDuration(
      FilamentEntity entity, int animationIndex) {
    // TODO: implement getAnimationDuration
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getAnimationNames(FilamentEntity entity) {
    // TODO: implement getAnimationNames
    throw UnimplementedError();
  }

  @override
  Future<List<String>> getMorphTargetNames(
      FilamentEntity entity, String meshName) {
    // TODO: implement getMorphTargetNames
    throw UnimplementedError();
  }

  @override
  String? getNameForEntity(FilamentEntity entity) {
    // TODO: implement getNameForEntity
    throw UnimplementedError();
  }

  @override
  Future hide(FilamentEntity entity, String meshName) {
    // TODO: implement hide
    throw UnimplementedError();
  }

  @override
  Future<FilamentEntity> loadGlb(String path, {bool unlit = false}) {
    // TODO: implement loadGlb
    throw UnimplementedError();
  }

  @override
  Future<FilamentEntity> loadGltf(String path, String relativeResourcePath) {
    // TODO: implement loadGltf
    throw UnimplementedError();
  }

  @override
  Future loadIbl(String lightingPath, {double intensity = 30000}) {
    // TODO: implement loadIbl
    throw UnimplementedError();
  }

  @override
  Future moveCameraToAsset(FilamentEntity entity) {
    // TODO: implement moveCameraToAsset
    throw UnimplementedError();
  }

  @override
  Future panEnd() {
    // TODO: implement panEnd
    throw UnimplementedError();
  }

  @override
  Future panStart(double x, double y) {
    // TODO: implement panStart
    throw UnimplementedError();
  }

  @override
  Future panUpdate(double x, double y) {
    // TODO: implement panUpdate
    throw UnimplementedError();
  }

  @override
  void pick(int x, int y) {
    // TODO: implement pick
  }

  @override
  Future playAnimation(FilamentEntity entity, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0}) {
    // TODO: implement playAnimation
    throw UnimplementedError();
  }

  @override
  Future removeAsset(FilamentEntity entity) {
    // TODO: implement removeAsset
    throw UnimplementedError();
  }

  @override
  Future removeIbl() {
    // TODO: implement removeIbl
    throw UnimplementedError();
  }

  @override
  Future removeLight(FilamentEntity light) {
    // TODO: implement removeLight
    throw UnimplementedError();
  }

  @override
  Future resize() {
    // TODO: implement resize
    throw UnimplementedError();
  }

  @override
  Future reveal(FilamentEntity entity, String meshName) {
    // TODO: implement reveal
    throw UnimplementedError();
  }

  @override
  Future rotateEnd() {
    // TODO: implement rotateEnd
    throw UnimplementedError();
  }

  @override
  Future rotateStart(double x, double y) {
    // TODO: implement rotateStart
    throw UnimplementedError();
  }

  @override
  Future rotateUpdate(double x, double y) {
    // TODO: implement rotateUpdate
    throw UnimplementedError();
  }

  @override
  Future setAnimationFrame(
      FilamentEntity entity, int index, int animationFrame) {
    // TODO: implement setAnimationFrame
    throw UnimplementedError();
  }

  @override
  Future setBackgroundColor(ui.Color color) {
    // TODO: implement setBackgroundColor
    throw UnimplementedError();
  }

  @override
  Future setBackgroundImage(String path, {bool fillHeight = false}) {
    // TODO: implement setBackgroundImage
    throw UnimplementedError();
  }

  @override
  Future setBackgroundImagePosition(double x, double y, {bool clamp = false}) {
    // TODO: implement setBackgroundImagePosition
    throw UnimplementedError();
  }

  @override
  Future setBloom(double bloom) {
    // TODO: implement setBloom
    throw UnimplementedError();
  }

  @override
  Future setBoneAnimation(FilamentEntity entity, BoneAnimationData animation) {
    // TODO: implement setBoneAnimation
    throw UnimplementedError();
  }

  @override
  Future setCamera(FilamentEntity entity, String? name) {
    // TODO: implement setCamera
    throw UnimplementedError();
  }

  @override
  Future setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity) {
    // TODO: implement setCameraExposure
    throw UnimplementedError();
  }

  @override
  Future setCameraFocalLength(double focalLength) {
    // TODO: implement setCameraFocalLength
    throw UnimplementedError();
  }

  @override
  Future setCameraFocusDistance(double focusDistance) {
    // TODO: implement setCameraFocusDistance
    throw UnimplementedError();
  }

  @override
  Future setCameraModelMatrix(List<double> matrix) {
    // TODO: implement setCameraModelMatrix
    throw UnimplementedError();
  }

  @override
  Future setCameraPosition(double x, double y, double z) {
    // TODO: implement setCameraPosition
    throw UnimplementedError();
  }

  @override
  Future setCameraRotation(double rads, double x, double y, double z) {
    // TODO: implement setCameraRotation
    throw UnimplementedError();
  }

  @override
  Future setFrameRate(int framerate) {
    // TODO: implement setFrameRate
    throw UnimplementedError();
  }

  @override
  Future setMaterialColor(FilamentEntity entity, String meshName,
      int materialIndex, ui.Color color) {
    // TODO: implement setMaterialColor
    throw UnimplementedError();
  }

  @override
  Future setMorphAnimationData(
      FilamentEntity entity, MorphAnimationData animation) {
    // TODO: implement setMorphAnimationData
    throw UnimplementedError();
  }

  @override
  Future setMorphTargetWeights(
      FilamentEntity entity, String meshName, List<double> weights) {
    // TODO: implement setMorphTargetWeights
    throw UnimplementedError();
  }

  @override
  Future setPosition(FilamentEntity entity, double x, double y, double z) {
    // TODO: implement setPosition
    throw UnimplementedError();
  }

  @override
  Future setPostProcessing(bool enabled) {
    // TODO: implement setPostProcessing
    throw UnimplementedError();
  }

  @override
  Future setRotation(
      FilamentEntity entity, double rads, double x, double y, double z) {
    // TODO: implement setRotation
    throw UnimplementedError();
  }

  @override
  Future setScale(FilamentEntity entity, double scale) {
    // TODO: implement setScale
    throw UnimplementedError();
  }

  @override
  Future setToneMapping(ToneMapper mapper) {
    // TODO: implement setToneMapping
    throw UnimplementedError();
  }

  @override
  Future setViewFrustumCulling(bool enabled) {
    // TODO: implement setViewFrustumCulling
    throw UnimplementedError();
  }

  @override
  Future stopAnimation(FilamentEntity entity, int animationIndex) {
    // TODO: implement stopAnimation
    throw UnimplementedError();
  }

  @override
  Future transformToUnitCube(FilamentEntity entity) {
    // TODO: implement transformToUnitCube
    throw UnimplementedError();
  }

  @override
  Future zoomBegin() {
    // TODO: implement zoomBegin
    throw UnimplementedError();
  }

  @override
  Future zoomEnd() {
    // TODO: implement zoomEnd
    throw UnimplementedError();
  }

  @override
  Future zoomUpdate(double x, double y, double z) {
    // TODO: implement zoomUpdate
    throw UnimplementedError();
  }

  @override
  Future setRendering(bool render) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    _rendering = render;
    set_rendering_ffi(_viewer, render);
  }

  @override
  Future render() async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    render_ffi(_viewer);
  }

  // @override
  // Future setFrameRate(int framerate) async {
  //   set_frame_interval_ffi(1.0 / framerate);
  // }

  @override
  Future setDimensions(Rect rect, double ratio) async {
    this.rect.value = Rect.fromLTWH(rect.left, rect.top,
        rect.width * _pixelRatio, rect.height * _pixelRatio);
    _pixelRatio = ratio;
  }

  // @override
  // Future destroy() async {
  //   await destroyViewer();
  //   await destroyTexture();
  // }

  // @override
  // Future destroyViewer() async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   var viewer = _viewer;

  //   _viewer = nullptr;

  //   _assetManager = nullptr;
  //   destroy_filament_viewer_ffi(viewer);
  // }

  // @override
  // Future destroyTexture() async {
  //   if (textureDetails.value != null) {
  //     await _channel.invokeMethod(
  //         "destroyTexture", textureDetails.value!.textureId);
  //   }
  //   print("Texture destroyed");
  // }

  ///
  /// Called by `FilamentWidget`. You do not need to call this yourself.
  ///
  @override
  Future createViewer() async {
    print("Creating viewer");
    if (rect.value == null) {
      throw Exception(
          "Dimensions have not yet been set by FilamentWidget. You need to wait for at least one frame after FilamentWidget has been inserted into the hierarchy");
    }
    if (_viewer != nullptr) {
      throw Exception(
          "Viewer already exists, make sure you call destroyViewer first");
    }
    if (textureDetails.value != null) {
      throw Exception(
          "Texture already exists, make sure you call destroyTexture first");
    }
    print("Getting resource loader");
    var loader = Pointer<Void>.fromAddress(
        await _channel.invokeMethod("getResourceLoaderWrapper"));
    print("Got loader ${loader.address}");
    if (loader == nullptr) {
      throw Exception("Failed to get resource loader");
    }

    if (!kIsWeb && Platform.isWindows && requiresTextureWidget) {
      _driver = Pointer<Void>.fromAddress(
          await _channel.invokeMethod("getDriverPlatform"));
    }

    var renderCallbackResult = await _channel.invokeMethod("getRenderCallback");
    print("Got renderCallbackResult $renderCallbackResult");
    var renderCallback =
        Pointer<NativeFunction<Void Function(Pointer<Void>)>>.fromAddress(
            renderCallbackResult[0]);
    var renderCallbackOwner =
        Pointer<Void>.fromAddress(renderCallbackResult[1]);

    var renderingSurface = await _createRenderingSurface();

    print("Obtained rendering surface, creating viewer");

    Pointer<Char> uberArchivePathPtr = nullptr;
    if (uberArchivePath != null) {
      uberArchivePathPtr = uberArchivePath!.toNativeUtf8().cast<Char>();
    }
    print("Using context ${renderingSurface.sharedContext}");
    // _viewer = create_filament_viewer(
    //   Pointer<Void>.fromAddress(renderingSurface.sharedContext),
    //   loader,
    //   _driver,
    //   uberArchivePathPtr,
    // );

    final out =
        Pointer<Pointer<Void>>.fromAddress(flutter_filament_web_allocate(1));
    create_filament_viewer_ffi(
        Pointer<Void>.fromAddress(renderingSurface.sharedContext),
        _driver,
        uberArchivePathPtr,
        loader,
        renderCallback,
        renderCallbackOwner,
        out);
    int address = 0;
    while (true) {
      address = flutter_filament_web_get_address(out);
      if (address != 0) {
        break;
      }
      await Future.delayed(const Duration(milliseconds: 10));
    }
    _viewer = Pointer<Void>.fromAddress(address);
    print("Created viewer ${_viewer.address}");
    if (_viewer.address == 0) {
      throw Exception("Failed to create viewer. Check logs for details");
    }

    _assetManager = get_asset_manager(_viewer);

    create_swap_chain_ffi(_viewer, renderingSurface.surface,
        rect.value!.width.toInt(), rect.value!.height.toInt());
    print("Created swap chain");
    if (renderingSurface.textureHandle != 0) {
      print(
          "Creating render target from native texture  ${renderingSurface.textureHandle}");
      create_render_target_ffi(_viewer, renderingSurface.textureHandle,
          rect.value!.width.toInt(), rect.value!.height.toInt());
    }

    textureDetails.value = TextureDetails(
        textureId: renderingSurface.flutterTextureId!,
        width: rect.value!.width.toInt(),
        height: rect.value!.height.toInt());
    print("texture details ${textureDetails.value}");
    update_viewport_and_camera_projection_ffi(
        _viewer, rect.value!.width.toInt(), rect.value!.height.toInt(), 1.0);
  }

  Future<RenderingSurface> _createRenderingSurface() async {
    return RenderingSurface.from(await _channel.invokeMethod("createTexture", [
      rect.value!.width,
      rect.value!.height,
      rect.value!.left,
      rect.value!.top
    ]));
  }

  // ///
  // /// When a FilamentWidget is resized, it will call the [resize] method below, which will tear down/recreate the swapchain.
  // /// For "once-off" resizes, this is fine; however, this can be problematic for consecutive resizes
  // /// (e.g. dragging to expand/contract the parent window on desktop, or animating the size of the FilamentWidget itself).
  // /// It is too expensive to recreate the swapchain multiple times per second.
  // /// We therefore add a timer to FilamentWidget so that the call to [resize] is delayed (e.g. 500ms).
  // /// Any subsequent resizes before the delay window elapses will cancel the earlier call.
  // ///
  // /// The overall process looks like this:
  // /// 1) the window is resized
  // /// 2) (Windows only) the Flutter engine requests PixelBufferTexture to provide a new pixel buffer with a new size (we return an empty texture, blanking the Texture widget)
  // /// 3) After Xms, [resize] is invoked
  // /// 4) the viewer is instructed to stop rendering (synchronous)
  // /// 5) the existing Filament swapchain is destroyed (synchronous)
  // /// 6) (where a Texture widget is used), the Flutter texture is unregistered
  // ///   a) this is asynchronous, but
  // ///   b) *** SEE NOTE BELOW ON WINDOWS *** by passing the method channel result through to the callback, we make this synchronous from the Flutter side,
  // ///    c) in this async callback, the glTexture is destroyed
  // /// 7) (where a backing window is used), the window is resized
  // /// 7) (where a Texture widget is used), a new Flutter/OpenGL texture is created (synchronous)
  // /// 8) a new swapchain is created (synchronous)
  // /// 9) if the viewer was rendering prior to the resize, the viewer is instructed to recommence rendering
  // /// 10) (where a Texture widget is used) the new texture ID is pushed to the FilamentWidget
  // /// 11) the FilamentWidget updates the Texture widget with the new texture.
  // ///
  // /// #### (Windows-only) ############################################################
  // /// # As soon as the widget/window is resized, the PixelBufferTexture will be
  // /// # requested to provide a new pixel buffer for the new size.
  // /// # Even with zero delay to the call to [resize], this will be triggered *before*
  // /// # we have had a chance to anything else (like tear down the swapchain).
  // /// # On the backend, we deal with this by simply returning an empty texture as soon
  // /// # as the size changes, and will rely on the followup call to [resize] to actually
  // /// # destroy/recreate the pixel buffer and Flutter texture.
  // ///
  // /// NOTE RE ASYNC CALLBACK
  // /// # The bigger problem is a race condition when resize is called multiple times in quick succession (e.g dragging to resize on Windows).
  // /// # It looks like occasionally, the backend OpenGL texture is being destroyed while its corresponding swapchain is still active, causing a crash.
  // /// # I'm not exactly sure how/where this is occurring, but something clearly isn't synchronized between destroy_swap_chain_ffi and
  // /// # the asynchronous callback passed to FlutterTextureRegistrar::UnregisterTexture.
  // /// # Theoretically this could occur if resize_2 starts before resize_1 completes, i.e.
  // /// # 1) resize_1 destroys swapchain/texture and creates new texture
  // /// # 2) resize_2 destroys swapchain/texture
  // /// # 3) resize_1 creates new swapchain but texture isn't available, ergo crash
  // /// #
  // /// # I don't think this should happen if:
  // /// # 1) we add a flag on the Flutter side to ensure only one call to destroy/recreate the swapchain/texture is active at any given time, and
  // /// # 2) on the Flutter side, we are sure that calling destroyTexture only returns once the async callback on the native side has completed.
  // /// # For (1), checking if textureId is null at the entrypoint should be sufficient.
  // /// # For (2), we invoke flutter::MethodResult<flutter::EncodableValue>->Success in the UnregisterTexture callback.
  // /// #
  // /// # Maybe (2) doesn't actually make Flutter wait?
  // /// #
  // /// # The other possibility is that both (1) and (2) are fine and the issue is elsewhere.
  // /// #
  // /// # Either way, the current solution is to basically setup a double-buffer on resize.
  // /// # When destroyTexture is called, the active texture isn't destroyed yet, it's only marked as inactive.
  // /// # On subsequent calls to destroyTexture, the inactive texture is destroyed.
  // /// # This seems to work fine.
  // ///
  // /// # Another option is to only use a single large (e.g. 4k) texture and simply crop whenever a resize is requested.
  // /// # This might be preferable for other reasons (e.g. don't need to destroy/recreate the pixel buffer or swapchain).
  // /// # Given we don't do this on other platforms, I'm OK to stick with the existing solution for the time being.
  // /// ############################################################################
  // ///
  // bool _resizing = false;
  // @override
  // Future resize() async {
  //   if (_viewer == nullptr) {
  //     throw Exception("Cannot resize without active viewer");
  //   }

  //   if (_resizing) {
  //     throw Exception("Resize currently underway, ignoring");
  //   }

  //   _resizing = true;

  //   set_rendering_ffi(_viewer, false);

  //   if (!_usesBackingWindow) {
  //     destroy_swap_chain_ffi(_viewer);
  //   }

  //   if (requiresTextureWidget) {
  //     if (textureDetails.value != null) {
  //       await _channel.invokeMethod(
  //           "destroyTexture", textureDetails.value!.textureId);
  //     }
  //   } else if (Platform.isWindows) {
  //     print("Resizing window with rect $rect");
  //     await _channel.invokeMethod("resizeWindow", [
  //       rect.value!.width,
  //       rect.value!.height,
  //       rect.value!.left,
  //       rect.value!.top
  //     ]);
  //   }

  //   var renderingSurface = await _createRenderingSurface();

  //   if (_viewer.address == 0) {
  //     throw Exception("Failed to create viewer. Check logs for details");
  //   }

  //   _assetManager = get_asset_manager(_viewer);

  //   if (!_usesBackingWindow) {
  //     create_swap_chain_ffi(_viewer, renderingSurface.surface,
  //         rect.value!.width.toInt(), rect.value!.height.toInt());
  //   }

  //   if (renderingSurface.textureHandle != 0) {
  //     print(
  //         "Creating render target from native texture  ${renderingSurface.textureHandle}");
  //     create_render_target_ffi(_viewer, renderingSurface.textureHandle,
  //         rect.value!.width.toInt(), rect.value!.height.toInt());
  //   }

  //   textureDetails.value = TextureDetails(
  //       textureId: renderingSurface.flutterTextureId!,
  //       width: rect.value!.width.toInt(),
  //       height: rect.value!.height.toInt());

  //   update_viewport_and_camera_projection_ffi(
  //       _viewer, rect.value!.width.toInt(), rect.value!.height.toInt(), 1.0);

  //   await setRendering(_rendering);

  //   _resizing = false;
  // }

  // @override
  // Future clearBackgroundImage() async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   clear_background_image_ffi(_viewer);
  // }

  // @override
  // Future setBackgroundImage(String path, {bool fillHeight = false}) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   set_background_image_ffi(
  //       _viewer, path.toNativeUtf8().cast<Char>(), fillHeight);
  // }

  // @override
  // Future setBackgroundColor(Color color) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   set_background_color_ffi(
  //       _viewer,
  //       color.red.toDouble() / 255.0,
  //       color.green.toDouble() / 255.0,
  //       color.blue.toDouble() / 255.0,
  //       color.alpha.toDouble() / 255.0);
  // }

  // @override
  // Future setBackgroundImagePosition(double x, double y,
  //     {bool clamp = false}) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   set_background_image_position_ffi(_viewer, x, y, clamp);
  // }

  @override
  Future loadSkybox(String skyboxPath) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    var ptr = Pointer<Void>.fromAddress(
        flutter_filament_web_allocate(skyboxPath.length + 1));
    var units = utf8.encode(skyboxPath);
    for (int i = 0; i < skyboxPath.length; i++) {
      flutter_filament_web_set(ptr, i, units[i]);
    }

    load_skybox_ffi(_viewer, ptr.cast<Char>());
  }

  // @override
  // Future loadIbl(String lightingPath, {double intensity = 30000}) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   load_ibl_ffi(_viewer, lightingPath.toNativeUtf8().cast<Char>(), intensity);
  // }

  @override
  Future removeSkybox() async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    remove_skybox_ffi(_viewer);
  }

  // @override
  // Future removeIbl() async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   // remove_ibl_ffi(_viewer);
  // }

  // @override
  // Future<FilamentEntity> addLight(
  //     int type,
  //     double colour,
  //     double intensity,
  //     double posX,
  //     double posY,
  //     double posZ,
  //     double dirX,
  //     double dirY,
  //     double dirZ,
  //     bool castShadows) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   var entity = add_light_ffi(_viewer, type, colour, intensity, posX, posY,
  //       posZ, dirX, dirY, dirZ, castShadows);
  //   return entity;
  // }

  // @override
  // Future removeLight(FilamentEntity light) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   remove_light_ffi(_viewer, light);
  // }

  // @override
  // Future clearLights() async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   clear_lights_ffi(_viewer);
  // }

  // @override
  // Future<FilamentEntity> loadGlb(String path, {bool unlit = false}) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   if (unlit) {
  //     throw Exception("Not yet implemented");
  //   }
  //   var asset =
  //       load_glb_ffi(_assetManager, path.toNativeUtf8().cast<Char>(), unlit);
  //   if (asset == _FILAMENT_ASSET_ERROR) {
  //     throw Exception("An error occurred loading the asset at $path");
  //   }
  //   return asset;
  // }

  // @override
  // Future<FilamentEntity> loadGltf(String path, String relativeResourcePath,
  //     {bool force = false}) async {
  //   if (Platform.isWindows && !force) {
  //     throw Exception(
  //         "loadGltf has a race condition on Windows which is likely to crash your program. If you really want to try, pass force=true to loadGltf");
  //   }
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   var asset = load_gltf_ffi(_assetManager, path.toNativeUtf8().cast<Char>(),
  //       relativeResourcePath.toNativeUtf8().cast<Char>());
  //   if (asset == _FILAMENT_ASSET_ERROR) {
  //     throw Exception("An error occurred loading the asset at $path");
  //   }
  //   return asset;
  // }

  // @override
  // Future panStart(double x, double y) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   grab_begin(_viewer, x * _pixelRatio, y * _pixelRatio, true);
  // }

  // @override
  // Future panUpdate(double x, double y) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   grab_update(_viewer, x * _pixelRatio, y * _pixelRatio);
  // }

  // @override
  // Future panEnd() async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   grab_end(_viewer);
  // }

  // @override
  // Future rotateStart(double x, double y) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   grab_begin(_viewer, x * _pixelRatio, y * _pixelRatio, false);
  // }

  // @override
  // Future rotateUpdate(double x, double y) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   grab_update(_viewer, x * _pixelRatio, y * _pixelRatio);
  // }

  // @override
  // Future rotateEnd() async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   grab_end(_viewer);
  // }

  // @override
  // Future setMorphTargetWeights(
  //     FilamentEntity asset, String meshName, List<double> weights) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   var weightsPtr = calloc<Float>(weights.length);

  //   for (int i = 0; i < weights.length; i++) {
  //     weightsPtr.elementAt(i).value = weights[i];
  //   }
  //   set_morph_target_weights_ffi(_assetManager, asset,
  //       meshName.toNativeUtf8().cast<Char>(), weightsPtr, weights.length);
  //   calloc.free(weightsPtr);
  // }

  // @override
  // Future<List<String>> getMorphTargetNames(
  //     FilamentEntity asset, String meshName) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   var names = <String>[];
  //   var count = get_morph_target_name_count_ffi(
  //       _assetManager, asset, meshName.toNativeUtf8().cast<Char>());
  //   var outPtr = calloc<Char>(255);
  //   for (int i = 0; i < count; i++) {
  //     get_morph_target_name(_assetManager, asset,
  //         meshName.toNativeUtf8().cast<Char>(), outPtr, i);
  //     names.add(outPtr.cast<Utf8>().toDartString());
  //   }
  //   calloc.free(outPtr);
  //   return names.cast<String>();
  // }

  // @override
  // Future<List<String>> getAnimationNames(FilamentEntity asset) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   var animationCount = get_animation_count(_assetManager, asset);
  //   var names = <String>[];
  //   var outPtr = calloc<Char>(255);
  //   for (int i = 0; i < animationCount; i++) {
  //     get_animation_name_ffi(_assetManager, asset, outPtr, i);
  //     names.add(outPtr.cast<Utf8>().toDartString());
  //   }

  //   return names;
  // }

  // @override
  // Future<double> getAnimationDuration(
  //     FilamentEntity asset, int animationIndex) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   var duration = get_animation_duration(_assetManager, asset, animationIndex);

  //   return duration;
  // }

  // @override
  // Future setMorphAnimationData(
  //     FilamentEntity entity, MorphAnimationData animation) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }

  //   var dataPtr = calloc<Float>(animation.data.length);
  //   for (int i = 0; i < animation.data.length; i++) {
  //     dataPtr.elementAt(i).value = animation.data[i];
  //   }

  //   // the morph targets in [animation] might be a subset of those that actually exist in the mesh (and might not have the same order)
  //   // we don't want to reorder the data (?? or do we? this is probably more efficient for the backend?)
  //   // so let's get the actual list of morph targets from the mesh and pass the relevant indices to the native side.
  //   var meshMorphTargets =
  //       await getMorphTargetNames(entity, animation.meshName);

  //   Pointer<Int> idxPtr = calloc<Int>(animation.morphTargets.length);
  //   for (int i = 0; i < animation.numMorphTargets; i++) {
  //     var index = meshMorphTargets.indexOf(animation.morphTargets[i]);
  //     if (index == -1) {
  //       calloc.free(dataPtr);
  //       calloc.free(idxPtr);
  //       throw Exception(
  //           "Morph target ${animation.morphTargets[i]} is specified in the animation but could not be found in the mesh ${animation.meshName} under entity ${entity}");
  //     }
  //     idxPtr.elementAt(i).value = index;
  //   }

  //   set_morph_animation(
  //       _assetManager,
  //       entity,
  //       animation.meshName.toNativeUtf8().cast<Char>(),
  //       dataPtr,
  //       idxPtr,
  //       animation.numMorphTargets,
  //       animation.numFrames,
  //       (animation.frameLengthInMs));
  //   calloc.free(dataPtr);
  //   calloc.free(idxPtr);
  // }

  // @override
  // Future setBoneAnimation(
  //     FilamentEntity asset, BoneAnimationData animation) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   // var data = calloc<Float>(animation.frameData.length);
  //   // int offset = 0;
  //   // var numFrames = animation.frameData.length ~/ 7;
  //   // var boneNames = calloc<Pointer<Char>>(1);
  //   // boneNames.elementAt(0).value =
  //   //     animation.boneName.toNativeUtf8().cast<Char>();

  //   // var meshNames = calloc<Pointer<Char>>(animation.meshNames.length);
  //   // for (int i = 0; i < animation.meshNames.length; i++) {
  //   //   meshNames.elementAt(i).value =
  //   //       animation.meshNames[i].toNativeUtf8().cast<Char>();
  //   // }

  //   // for (int i = 0; i < animation.frameData.length; i++) {
  //   //   data.elementAt(offset).value = animation.frameData[i];
  //   //   offset += 1;
  //   // }

  //   // await _channel.invokeMethod("setBoneAnimation", [
  //   //   _assetManager,
  //   //   asset,
  //   //   data,
  //   //   numFrames,
  //   //   1,
  //   //   boneNames,
  //   //   meshNames,
  //   //   animation.meshNames.length,
  //   //   animation.frameLengthInMs
  //   // ]);
  //   // calloc.free(data);
  // }

  // @override
  // Future removeAsset(FilamentEntity asset) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   // remove_asset_ffi(_viewer, asset);
  // }

  // @override
  // Future clearAssets() async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   // clear_assets_ffi(_viewer);
  // }

  // @override
  // Future zoomBegin() async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   // scroll_begin(_viewer);
  // }

  // @override
  // Future zoomUpdate(double x, double y, double z) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   // scroll_update(_viewer, x, y, z);
  // }

  // @override
  // Future zoomEnd() async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   // scroll_end(_viewer);
  // }

  // @override
  // Future playAnimation(FilamentEntity asset, int index,
  //     {bool loop = false,
  //     bool reverse = false,
  //     bool replaceActive = true,
  //     double crossfade = 0.0}) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   // play_animation_ffi(
  //   //     _assetManager, asset, index, loop, reverse, replaceActive, crossfade);
  // }

  // @override
  // Future setAnimationFrame(
  //     FilamentEntity asset, int index, int animationFrame) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   set_animation_frame(_assetManager, asset, index, animationFrame);
  // }

  // @override
  // Future stopAnimation(FilamentEntity asset, int animationIndex) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   stop_animation(_assetManager, asset, animationIndex);
  // }

  // @override
  // Future setCamera(FilamentEntity asset, String? name) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   var result = set_camera(
  //       _viewer, asset, name?.toNativeUtf8().cast<Char>() ?? nullptr);
  //   if (!result) {
  //     throw Exception("Failed to set camera");
  //   }
  // }

  // @override
  // Future setToneMapping(ToneMapper mapper) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }

  //   set_tone_mapping_ffi(_viewer, mapper.index);
  // }

  // @override
  // Future setPostProcessing(bool enabled) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }

  //   set_post_processing_ffi(_viewer, enabled);
  // }

  // @override
  // Future setBloom(double bloom) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   set_bloom_ffi(_viewer, bloom);
  // }

  // @override
  // Future setCameraFocalLength(double focalLength) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   set_camera_focal_length(_viewer, focalLength);
  // }

  // @override
  // Future setCameraFocusDistance(double focusDistance) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   set_camera_focus_distance(_viewer, focusDistance);
  // }

  // @override
  // Future setCameraPosition(double x, double y, double z) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   set_camera_position(_viewer, x, y, z);
  // }

  // @override
  // Future moveCameraToAsset(FilamentEntity asset) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   move_camera_to_asset(_viewer, asset);
  // }

  // @override
  // Future setViewFrustumCulling(bool enabled) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   set_view_frustum_culling(_viewer, enabled);
  // }

  // @override
  // Future setCameraExposure(
  //     double aperture, double shutterSpeed, double sensitivity) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   set_camera_exposure(_viewer, aperture, shutterSpeed, sensitivity);
  // }

  // @override
  // Future setCameraRotation(double rads, double x, double y, double z) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   set_camera_rotation(_viewer, rads, x, y, z);
  // }

  // @override
  // Future setCameraModelMatrix(List<double> matrix) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   assert(matrix.length == 16);
  //   var ptr = calloc<Float>(16);
  //   for (int i = 0; i < 16; i++) {
  //     ptr.elementAt(i).value = matrix[i];
  //   }
  //   set_camera_model_matrix(_viewer, ptr);
  //   calloc.free(ptr);
  // }

  // @override
  // Future setMaterialColor(FilamentEntity asset, String meshName,
  //     int materialIndex, Color color) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   var result = set_material_color(
  //       _assetManager,
  //       asset,
  //       meshName.toNativeUtf8().cast<Char>(),
  //       materialIndex,
  //       color.red.toDouble() / 255.0,
  //       color.green.toDouble() / 255.0,
  //       color.blue.toDouble() / 255.0,
  //       color.alpha.toDouble() / 255.0);
  //   if (result != 1) {
  //     throw Exception("Failed to set material color");
  //   }
  // }

  // @override
  // Future transformToUnitCube(FilamentEntity asset) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   transform_to_unit_cube(_assetManager, asset);
  // }

  // @override
  // Future setPosition(FilamentEntity asset, double x, double y, double z) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   set_position(_assetManager, asset, x, y, z);
  // }

  // @override
  // Future setScale(FilamentEntity asset, double scale) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   set_scale(_assetManager, asset, scale);
  // }

  // @override
  // Future setRotation(
  //     FilamentEntity asset, double rads, double x, double y, double z) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   set_rotation(_assetManager, asset, rads, x, y, z);
  // }

  // @override
  // Future hide(FilamentEntity asset, String meshName) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   if (hide_mesh(_assetManager, asset, meshName.toNativeUtf8().cast<Char>()) !=
  //       1) {}
  // }

  // @override
  // Future reveal(FilamentEntity asset, String meshName) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   if (reveal_mesh(
  //           _assetManager, asset, meshName.toNativeUtf8().cast<Char>()) !=
  //       1) {
  //     throw Exception("Failed to reveal mesh $meshName");
  //   }
  // }

  // @override
  // String? getNameForEntity(FilamentEntity entity) {
  //   final result = get_name_for_entity(_assetManager, entity);
  //   if (result == nullptr) {
  //     return null;
  //   }
  //   return result.cast<Utf8>().toDartString();
  // }

  // @override
  // void pick(int x, int y) async {
  //   if (_viewer == nullptr) {
  //     throw Exception("No viewer available, ignoring");
  //   }
  //   final outPtr = calloc<EntityId>(1);
  //   outPtr.value = 0;

  //   pick_ffi(_viewer, x, textureDetails.value!.height - y, outPtr);
  //   int wait = 0;
  //   while (outPtr.value == 0) {
  //     await Future.delayed(const Duration(milliseconds: 50));
  //     wait++;
  //     if (wait > 10) {
  //       calloc.free(outPtr);
  //       throw Exception("Failed to get picking result");
  //     }
  //   }
  //   var entityId = outPtr.value;
  //   _pickResultController.add(entityId);
  //   calloc.free(outPtr);
  // }
}
