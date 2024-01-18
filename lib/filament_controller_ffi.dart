import 'dart:async';
import 'dart:ui' as ui;
import 'dart:developer' as dev;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_filament/filament_controller.dart';
import 'package:flutter_filament/animations/animation_data.dart';
import 'package:flutter_filament/rendering_surface.dart';
import 'package:vector_math/vector_math_64.dart';

import 'ffi/ffi.dart';

// ignore: constant_identifier_names
const FilamentEntity _FILAMENT_ASSET_ERROR = 0;

class FilamentControllerFFI extends FilamentController {
  final _channel = const MethodChannel("app.polyvox.filament/event");

  ///
  /// This will be set on constructor invocation.
  /// On Windows, this will be set to the value returned by the [usesBackingWindow] method call.
  /// On Web, this will always be true;
  /// On other platforms, this will always be false.
  ///
  bool _usesBackingWindow = false;

  @override
  bool get requiresTextureWidget => !_usesBackingWindow;

  double _pixelRatio = 1.0;

  late Pointer<Void> _assetManager;

  late Pointer<Void> _viewer;

  final String? uberArchivePath;

  late Pointer<Void> _driver;

  @override
  final _rect = ValueNotifier<Rect?>(null);
  final _rectCompleter = Completer<Rect?>();

  @override
  final hasViewer = ValueNotifier<bool>(false);

  @override
  Stream<FilamentEntity> get pickResult => _pickResultController.stream;
  final _pickResultController = StreamController<FilamentEntity>.broadcast();

  int? _resizingWidth;
  int? _resizingHeight;

  Timer? _resizeTimer;

  final _lights = <FilamentEntity>{};
  final _entities = <FilamentEntity>{};

  final _onLoadController = StreamController<FilamentEntity>.broadcast();
  Stream<FilamentEntity> get onLoad => _onLoadController.stream;

  final _onUnloadController = StreamController<FilamentEntity>.broadcast();
  Stream<FilamentEntity> get onUnload => _onUnloadController.stream;

  ///
  /// This controller uses platform channels to bridge Dart with the C/C++ code for the Filament API.
  /// Setting up the context/texture (since this is platform-specific) and the render ticker are platform-specific; all other methods are passed through by the platform channel to the methods specified in FlutterFilamentApi.h.
  ///
  FilamentControllerFFI({this.uberArchivePath}) {
    _assetManager = nullptr;
    _viewer = nullptr;
    _driver = nullptr;

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
        _rect.value = Offset.zero &
            ui.Size(_resizingWidth!.toDouble(), _resizingHeight!.toDouble());
        await resize();
      });
    });
    // late DynamicLibrary dl;
    // if (!kIsWeb) {
    //   if (Platform.isIOS || Platform.isMacOS || Platform.isWindows) {
    //     dl = DynamicLibrary.process();
    //   } else {
    //     dl = DynamicLibrary.open("libflutter_filament_android.so");
    //   }
    //   if (Platform.isWindows) {
    //     _channel.invokeMethod("usesBackingWindow").then((result) {
    //       _usesBackingWindow = result;
    //     });
    //   }
    // }
  }

  bool _rendering = false;
  @override
  bool get rendering => _rendering;

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

  @override
  Future setFrameRate(int framerate) async {
    final interval = 1000.0 / framerate;
    set_frame_interval_ffi(interval);
    print("Set frame interval to $interval");
  }

  @override
  Future setDimensions(Rect rect, double pixelRatio) async {
    this._rect.value = Rect.fromLTWH(
        (rect.left * _pixelRatio).floor().toDouble(),
        rect.top * _pixelRatio.floor().toDouble(),
        (rect.width * _pixelRatio).ceil().toDouble(),
        (rect.height * _pixelRatio).ceil().toDouble());
    if (!_rectCompleter.isCompleted) {
      _rectCompleter.complete(this._rect.value);
    }
    _pixelRatio = pixelRatio;
  }

  @override
  Future destroy() async {
    await destroyViewer();
    await destroyTexture();
  }

  @override
  Future destroyViewer() async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    var viewer = _viewer;

    _viewer = nullptr;

    _assetManager = nullptr;
    destroy_filament_viewer_ffi(viewer);
    hasViewer.value = false;
  }

  @override
  Future destroyTexture() async {
    if (textureDetails.value != null) {
      await _channel.invokeMethod(
          "destroyTexture", textureDetails.value!.textureId);
    }
    print("Texture destroyed");
  }

  bool _creating = false;

  ///
  /// Called by `FilamentWidget`. You do not need to call this yourself.
  ///
  @override
  Future createViewer({bool async = false}) async {
    if (_creating) {
      throw Exception(
          "An existing call to createViewer is pending completion.");
    }
    _creating = true;
    print("Waiting for widget dimensions to become available..");
    await _rectCompleter.future;
    print("Got widget dimensions : ${_rect.value}");
    if (_rect.value == null) {
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

    print("Getting resource loader address");

    var loader = Pointer<Void>.fromAddress(
        await _channel.invokeMethod("getResourceLoaderWrapper"));
    if (loader == nullptr) {
      throw Exception("Failed to get resource loader");
    }

    print("Got resource loader address, getting render callback");

    // if (!kIsWeb && Platform.isWindows && requiresTextureWidget) {
    //   _driver = Pointer<Void>.fromAddress(
    //       await _channel.invokeMethod("getDriverPlatform"));
    // }

    var renderCallbackResult = await _channel.invokeMethod("getRenderCallback");
    var renderCallback =
        Pointer<NativeFunction<Void Function(Pointer<Void>)>>.fromAddress(
            renderCallbackResult[0]);
    var renderCallbackOwner =
        Pointer<Void>.fromAddress(renderCallbackResult[1]);

    var renderingSurface = await _createRenderingSurface();

    final uberarchivePtr = uberArchivePath != null
        ? uberArchivePath!.toNativeUtf8(allocator: allocator).cast<Char>()
        : nullptr.cast<Char>();

    if (async) {
      final out = allocator<Pointer<Void>>();

      create_filament_viewer_async_ffi(
          Pointer<Void>.fromAddress(renderingSurface.sharedContext),
          _driver,
          uberarchivePtr,
          loader,
          renderCallback,
          renderCallbackOwner,
          out);
      int iter = 0;
      while (out.value == nullptr) {
        await Future.delayed(const Duration(milliseconds: 20));
        if (iter > 100) {
          throw Exception("Timeout trying to instantiate async viewer");
        }
        iter++;
        _viewer = out.value;
        allocator.free(out);
      }
    } else {
      _viewer = create_filament_viewer_ffi(
          Pointer<Void>.fromAddress(renderingSurface.sharedContext),
          _driver,
          uberarchivePtr,
          loader,
          renderCallback,
          renderCallbackOwner);
    }
    print("Created viewer");
    if (_viewer == nullptr) {
      throw Exception("Failed to create viewer. Check logs for details");
    }

    _assetManager = get_asset_manager(_viewer);

    create_swap_chain_ffi(_viewer, renderingSurface.surface,
        _rect.value!.width.toInt(), _rect.value!.height.toInt());

    if (renderingSurface.textureHandle != 0) {
      create_render_target_ffi(_viewer, renderingSurface.textureHandle,
          _rect.value!.width.toInt(), _rect.value!.height.toInt());
    }

    textureDetails.value = TextureDetails(
        textureId: renderingSurface.flutterTextureId,
        width: _rect.value!.width.toInt(),
        height: _rect.value!.height.toInt());

    update_viewport_and_camera_projection_ffi(
        _viewer, _rect.value!.width.toInt(), _rect.value!.height.toInt(), 1.0);
    hasViewer.value = true;
    _creating = false;
  }

  Future<RenderingSurface> _createRenderingSurface() async {
    return RenderingSurface.from(await _channel.invokeMethod("createTexture", [
      _rect.value!.width,
      _rect.value!.height,
      _rect.value!.left,
      _rect.value!.top
    ]));
  }

  ///
  /// When a FilamentWidget is resized, it will call the [resize] method below, which will tear down/recreate the swapchain.
  /// For "once-off" resizes, this is fine; however, this can be problematic for consecutive resizes
  /// (e.g. dragging to expand/contract the parent window on desktop, or animating the size of the FilamentWidget itself).
  /// It is too expensive to recreate the swapchain multiple times per second.
  /// We therefore add a timer to FilamentWidget so that the call to [resize] is delayed (e.g. 500ms).
  /// Any subsequent resizes before the delay window elapses will cancel the earlier call.
  ///
  /// The overall process looks like this:
  /// 1) the window is resized
  /// 2) (Windows only) the Flutter engine requests PixelBufferTexture to provide a new pixel buffer with a new size (we return an empty texture, blanking the Texture widget)
  /// 3) After Xms, [resize] is invoked
  /// 4) the viewer is instructed to stop rendering (synchronous)
  /// 5) the existing Filament swapchain is destroyed (synchronous)
  /// 6) (where a Texture widget is used), the Flutter texture is unregistered
  ///   a) this is asynchronous, but
  ///   b) *** SEE NOTE BELOW ON WINDOWS *** by passing the method channel result through to the callback, we make this synchronous from the Flutter side,
  ///    c) in this async callback, the glTexture is destroyed
  /// 7) (where a backing window is used), the window is resized
  /// 7) (where a Texture widget is used), a new Flutter/OpenGL texture is created (synchronous)
  /// 8) a new swapchain is created (synchronous)
  /// 9) if the viewer was rendering prior to the resize, the viewer is instructed to recommence rendering
  /// 10) (where a Texture widget is used) the new texture ID is pushed to the FilamentWidget
  /// 11) the FilamentWidget updates the Texture widget with the new texture.
  ///
  /// #### (Windows-only) ############################################################
  /// # As soon as the widget/window is resized, the PixelBufferTexture will be
  /// # requested to provide a new pixel buffer for the new size.
  /// # Even with zero delay to the call to [resize], this will be triggered *before*
  /// # we have had a chance to anything else (like tear down the swapchain).
  /// # On the backend, we deal with this by simply returning an empty texture as soon
  /// # as the size changes, and will rely on the followup call to [resize] to actually
  /// # destroy/recreate the pixel buffer and Flutter texture.
  ///
  /// NOTE RE ASYNC CALLBACK
  /// # The bigger problem is a race condition when resize is called multiple times in quick succession (e.g dragging to resize on Windows).
  /// # It looks like occasionally, the backend OpenGL texture is being destroyed while its corresponding swapchain is still active, causing a crash.
  /// # I'm not exactly sure how/where this is occurring, but something clearly isn't synchronized between destroy_swap_chain_ffi and
  /// # the asynchronous callback passed to FlutterTextureRegistrar::UnregisterTexture.
  /// # Theoretically this could occur if resize_2 starts before resize_1 completes, i.e.
  /// # 1) resize_1 destroys swapchain/texture and creates new texture
  /// # 2) resize_2 destroys swapchain/texture
  /// # 3) resize_1 creates new swapchain but texture isn't available, ergo crash
  /// #
  /// # I don't think this should happen if:
  /// # 1) we add a flag on the Flutter side to ensure only one call to destroy/recreate the swapchain/texture is active at any given time, and
  /// # 2) on the Flutter side, we are sure that calling destroyTexture only returns once the async callback on the native side has completed.
  /// # For (1), checking if textureId is null at the entrypoint should be sufficient.
  /// # For (2), we invoke flutter::MethodResult<flutter::EncodableValue>->Success in the UnregisterTexture callback.
  /// #
  /// # Maybe (2) doesn't actually make Flutter wait?
  /// #
  /// # The other possibility is that both (1) and (2) are fine and the issue is elsewhere.
  /// #
  /// # Either way, the current solution is to basically setup a double-buffer on resize.
  /// # When destroyTexture is called, the active texture isn't destroyed yet, it's only marked as inactive.
  /// # On subsequent calls to destroyTexture, the inactive texture is destroyed.
  /// # This seems to work fine.
  ///
  /// # Another option is to only use a single large (e.g. 4k) texture and simply crop whenever a resize is requested.
  /// # This might be preferable for other reasons (e.g. don't need to destroy/recreate the pixel buffer or swapchain).
  /// # Given we don't do this on other platforms, I'm OK to stick with the existing solution for the time being.
  /// ############################################################################
  ///
  bool _resizing = false;
  @override
  Future resize() async {
    if (_viewer == nullptr) {
      throw Exception("Cannot resize without active viewer");
    }
    int iter = 0;
    while (_resizing) {
      await Future.delayed(Duration(milliseconds: 100));
      if (iter > 10) {
        throw Exception("Timed out waiting for previous resize to complete");
      }
      iter++;
    }

    try {
      print("Resizing to ${_rect.value}");
      _resizing = true;

      set_rendering_ffi(_viewer, false);

      if (!_usesBackingWindow) {
        destroy_swap_chain_ffi(_viewer);
      }

      if (requiresTextureWidget) {
        if (textureDetails.value != null) {
          await _channel.invokeMethod(
              "destroyTexture", textureDetails.value!.textureId);
        }
      }
      // else if (!kIsWeb && Platform.isWindows) {
      //   print("Resizing window with rect $_rect");
      //   await _channel.invokeMethod("resizeWindow", [
      //     _rect.value!.width,
      //     _rect.value!.height,
      //     _rect.value!.left,
      //     _rect.value!.top
      //   ]);
      // }

      var renderingSurface = await _createRenderingSurface();

      if (_viewer.address == 0) {
        throw Exception("Failed to create viewer. Check logs for details");
      }

      _assetManager = get_asset_manager(_viewer);

      if (!_usesBackingWindow) {
        create_swap_chain_ffi(_viewer, renderingSurface.surface,
            _rect.value!.width.toInt(), _rect.value!.height.toInt());
      }

      if (renderingSurface.textureHandle != 0) {
        print(
            "Creating render target from native texture  ${renderingSurface.textureHandle}");
        create_render_target_ffi(_viewer, renderingSurface.textureHandle,
            _rect.value!.width.toInt(), _rect.value!.height.toInt());
      }

      textureDetails.value = TextureDetails(
          textureId: renderingSurface.flutterTextureId,
          width: _rect.value!.width.toInt(),
          height: _rect.value!.height.toInt());

      update_viewport_and_camera_projection_ffi(_viewer,
          _rect.value!.width.toInt(), _rect.value!.height.toInt(), 1.0);

      await setRendering(_rendering);
    } finally {
      _resizing = false;
    }
  }

  @override
  Future clearBackgroundImage() async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    clear_background_image_ffi(_viewer);
  }

  @override
  Future setBackgroundImage(String path, {bool fillHeight = false}) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    set_background_image_ffi(_viewer,
        path.toNativeUtf8(allocator: allocator).cast<Char>(), fillHeight);
  }

  @override
  Future setBackgroundColor(Color color) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    set_background_color_ffi(
        _viewer,
        color.red.toDouble() / 255.0,
        color.green.toDouble() / 255.0,
        color.blue.toDouble() / 255.0,
        color.alpha.toDouble() / 255.0);
  }

  @override
  Future setBackgroundImagePosition(double x, double y,
      {bool clamp = false}) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    set_background_image_position_ffi(_viewer, x, y, clamp);
  }

  @override
  Future loadSkybox(String skyboxPath, {bool async = false}) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }

    var ptr = skyboxPath.toNativeUtf8(allocator: allocator);
    load_skybox_ffi(_viewer, ptr.cast<Char>(), async);
    allocator.free(ptr);
  }

  @override
  Future loadIbl(String lightingPath,
      {double intensity = 30000, bool async = false}) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    load_ibl_ffi(
        _viewer,
        lightingPath.toNativeUtf8(allocator: allocator).cast<Char>(),
        intensity,
        async);
  }

  @override
  Future rotateIbl(Matrix3 rotationMatrix) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    var floatPtr = allocator<Float>(9);
    for (int i = 0; i < 9; i++) {
      floatPtr.elementAt(i).value = rotationMatrix.storage[i];
    }
    rotate_ibl(_viewer, floatPtr);
    allocator.free(floatPtr);
  }

  @override
  Future removeSkybox() async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    remove_skybox_ffi(_viewer);
  }

  @override
  Future removeIbl() async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    remove_ibl_ffi(_viewer);
  }

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
      bool castShadows) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    var entity = add_light_ffi(_viewer, type, colour, intensity, posX, posY,
        posZ, dirX, dirY, dirZ, castShadows);
    _onLoadController.sink.add(entity);
    _lights.add(entity);
    return entity;
  }

  @override
  Future removeLight(FilamentEntity entity) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    _lights.remove(entity);
    remove_light_ffi(_viewer, entity);
    _onUnloadController.add(entity);
  }

  @override
  Future clearLights() async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    clear_lights_ffi(_viewer);
    for (final entity in _lights) {
      _onUnloadController.add(entity);
    }
    _lights.clear();
  }

  @override
  Future<FilamentEntity> loadGlb(String path,
      {bool unlit = false, bool async = false}) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    if (unlit) {
      throw Exception("Not yet implemented");
    }
    late FilamentEntity entity;
    if (!async) {
      entity = load_glb_ffi(
          _assetManager, path.toNativeUtf8(allocator: allocator).cast<Char>());
    } else {
      print("Loading GLB async");
      Pointer<Int32> out = allocator<EntityId>(1);
      out.value = -1;
      load_glb_async_ffi(_assetManager,
          path.toNativeUtf8(allocator: allocator).cast<Char>(), out);
      int iters = 0;
      while (out.value == -1) {
        await Future.delayed(const Duration(milliseconds: 10));
        iters++;
        if (iters > 3000) {
          throw Exception("Failed to load async");
        } else if (iters % 100 == 0) {
          print("Waiting for asset load to complete");
        }
      }
      print("Async GLB load completed");
      entity = out.value;
    }
    if (entity == _FILAMENT_ASSET_ERROR) {
      throw Exception("An error occurred loading the asset at $path");
    }
    _entities.add(entity);
    _onLoadController.sink.add(entity);
    return entity;
  }

  @override
  Future<FilamentEntity> loadGltf(String path, String relativeResourcePath,
      {bool force = false}) async {
    // if (!kIsWeb && Platform.isWindows && !force) {
    //   throw Exception(
    //       "loadGltf has a race condition on Windows which is likely to crash your program. If you really want to try, pass force=true to loadGltf");
    // }
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    var entity = load_gltf_ffi(
        _assetManager,
        path.toNativeUtf8(allocator: allocator).cast<Char>(),
        relativeResourcePath.toNativeUtf8(allocator: allocator).cast<Char>());
    if (entity == _FILAMENT_ASSET_ERROR) {
      throw Exception("An error occurred loading the asset at $path");
    }
    _entities.add(entity);
    _onLoadController.sink.add(entity);
    return entity;
  }

  @override
  Future panStart(double x, double y) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    grab_begin(_viewer, x * _pixelRatio, y * _pixelRatio, true);
  }

  @override
  Future panUpdate(double x, double y) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    grab_update(_viewer, x * _pixelRatio, y * _pixelRatio);
  }

  @override
  Future panEnd() async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    grab_end(_viewer);
  }

  @override
  Future rotateStart(double x, double y) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    grab_begin(_viewer, x * _pixelRatio, y * _pixelRatio, false);
  }

  @override
  Future rotateUpdate(double x, double y) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    grab_update(_viewer, x * _pixelRatio, y * _pixelRatio);
  }

  @override
  Future rotateEnd() async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    grab_end(_viewer);
  }

  @override
  Future setMorphTargetWeights(
      FilamentEntity entity, String meshName, List<double> weights) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    var weightsPtr = allocator<Float>(weights.length);

    for (int i = 0; i < weights.length; i++) {
      weightsPtr.elementAt(i).value = weights[i];
    }
    var meshNamePtr = meshName.toNativeUtf8(allocator: allocator).cast<Char>();
    set_morph_target_weights_ffi(
        _assetManager, entity, meshNamePtr, weightsPtr, weights.length);
    allocator.free(weightsPtr);
    allocator.free(meshNamePtr);
  }

  @override
  Future<List<String>> getMorphTargetNames(
      FilamentEntity entity, String meshName) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    var names = <String>[];
    var count = get_morph_target_name_count_ffi(_assetManager, entity,
        meshName.toNativeUtf8(allocator: allocator).cast<Char>());
    var outPtr = allocator<Char>(255);
    for (int i = 0; i < count; i++) {
      get_morph_target_name(_assetManager, entity,
          meshName.toNativeUtf8(allocator: allocator).cast<Char>(), outPtr, i);
      names.add(outPtr.cast<Utf8>().toDartString());
    }
    allocator.free(outPtr);
    return names.cast<String>();
  }

  @override
  Future<List<String>> getAnimationNames(FilamentEntity entity) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    var animationCount = get_animation_count(_assetManager, entity);
    var names = <String>[];
    var outPtr = allocator<Char>(255);
    for (int i = 0; i < animationCount; i++) {
      get_animation_name_ffi(_assetManager, entity, outPtr, i);
      names.add(outPtr.cast<Utf8>().toDartString());
    }

    return names;
  }

  @override
  Future<double> getAnimationDuration(
      FilamentEntity entity, int animationIndex) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    var duration =
        get_animation_duration(_assetManager, entity, animationIndex);

    return duration;
  }

  @override
  Future setMorphAnimationData(
      FilamentEntity entity, MorphAnimationData animation) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }

    var dataPtr = allocator<Float>(animation.data.length);

    for (int i = 0; i < animation.data.length; i++) {
      dataPtr.elementAt(i).value = animation.data[i];
    }

    Pointer<Int> idxPtr = allocator<Int>(animation.morphTargets.length);

    for (var meshName in animation.meshNames) {
      // the morph targets in [animation] might be a subset of those that actually exist in the mesh (and might not have the same order)
      // we don't want to reorder the data (?? or do we? this is probably more efficient for the backend?)
      // so let's get the actual list of morph targets from the mesh and pass the relevant indices to the native side.
      var meshMorphTargets = await getMorphTargetNames(entity, meshName);

      for (int i = 0; i < animation.numMorphTargets; i++) {
        var index = meshMorphTargets.indexOf(animation.morphTargets[i]);
        if (index == -1) {
          allocator.free(dataPtr);
          allocator.free(idxPtr);
          throw Exception(
              "Morph target ${animation.morphTargets[i]} is specified in the animation but could not be found in the mesh $meshName under entity $entity");
        }
        idxPtr.elementAt(i).value = index;
      }

      var meshNamePtr =
          meshName.toNativeUtf8(allocator: allocator).cast<Char>();
      set_morph_animation_ffi(
          _assetManager,
          entity,
          meshNamePtr,
          dataPtr,
          idxPtr,
          animation.numMorphTargets,
          animation.numFrames,
          (animation.frameLengthInMs));
      allocator.free(meshNamePtr);
    }
    allocator.free(dataPtr);
    allocator.free(idxPtr);
  }

  @override
  Future resetBones(FilamentEntity entity) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    reset_to_rest_pose_ffi(_assetManager, entity);
  }

  @override
  Future addBoneAnimation(
      FilamentEntity entity, BoneAnimationData animation) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }

    var numFrames = animation.rotationFrameData.length;

    var meshNames = allocator<Pointer<Char>>(animation.meshNames.length);
    for (int i = 0; i < animation.meshNames.length; i++) {
      meshNames.elementAt(i).value = animation.meshNames[i]
          .toNativeUtf8(allocator: allocator)
          .cast<Char>();
    }

    var data = allocator<Float>(numFrames * 16);

    for (var boneIndex = 0; boneIndex < animation.bones.length; boneIndex++) {
      var bone = animation.bones[boneIndex];
      var boneNamePtr = bone.toNativeUtf8(allocator: allocator).cast<Char>();

      for (int i = 0; i < numFrames; i++) {
        var rotation = animation.rotationFrameData[i][boneIndex];
        var translation = animation.translationFrameData[i][boneIndex];
        var mat4 = Matrix4.compose(translation, rotation, Vector3.all(1.0));
        for (int j = 0; j < 16; j++) {
          data.elementAt((i * 16) + j).value = mat4.storage[j];
        }
      }

      add_bone_animation(
          _assetManager,
          entity,
          data,
          numFrames,
          boneNamePtr,
          meshNames,
          animation.meshNames.length,
          animation.frameLengthInMs,
          animation.isModelSpace);
      allocator.free(boneNamePtr);
    }
    allocator.free(data);
    allocator.free(meshNames);
  }

  @override
  Future removeAsset(FilamentEntity entity) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    _entities.remove(entity);
    remove_asset_ffi(_viewer, entity);
    _onUnloadController.add(entity);
  }

  @override
  Future clearAssets() async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    clear_assets_ffi(_viewer);

    for (final entity in _entities) {
      _onUnloadController.add(entity);
    }
    _entities.clear();
  }

  @override
  Future zoomBegin() async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    scroll_begin(_viewer);
  }

  @override
  Future zoomUpdate(double x, double y, double z) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    scroll_update(_viewer, x, y, z);
  }

  @override
  Future zoomEnd() async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    scroll_end(_viewer);
  }

  @override
  Future playAnimation(FilamentEntity entity, int index,
      {bool loop = false,
      bool reverse = false,
      bool replaceActive = true,
      double crossfade = 0.0}) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    play_animation_ffi(
        _assetManager, entity, index, loop, reverse, replaceActive, crossfade);
  }

  @override
  Future setAnimationFrame(
      FilamentEntity entity, int index, int animationFrame) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    set_animation_frame(_assetManager, entity, index, animationFrame);
  }

  @override
  Future stopAnimation(FilamentEntity entity, int animationIndex) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    stop_animation(_assetManager, entity, animationIndex);
  }

  @override
  Future setCamera(FilamentEntity entity, String? name) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    final namePtr = name != null
        ? name.toNativeUtf8(allocator: allocator).cast<Char>()
        : nullptr.cast<Char>();
    var result = set_camera(_viewer, entity, namePtr);
    if (!result) {
      throw Exception("Failed to set camera");
    }
    allocator.free(namePtr);
  }

  @override
  Future setToneMapping(ToneMapper mapper) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }

    set_tone_mapping_ffi(_viewer, mapper.index);
  }

  @override
  Future setPostProcessing(bool enabled) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }

    set_post_processing_ffi(_viewer, enabled);
  }

  @override
  Future setBloom(double bloom) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    set_bloom_ffi(_viewer, bloom);
  }

  @override
  Future setCameraFocalLength(double focalLength) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    set_camera_focal_length(_viewer, focalLength);
  }

  @override
  Future setCameraCulling(double near, double far) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    set_camera_culling(_viewer, near, far);
  }

  @override
  Future<double> getCameraCullingNear() async {
    return get_camera_culling_near(_viewer);
  }

  @override
  Future<double> getCameraCullingFar() async {
    return get_camera_culling_far(_viewer);
  }

  @override
  Future setCameraFocusDistance(double focusDistance) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    set_camera_focus_distance(_viewer, focusDistance);
  }

  @override
  Future setCameraPosition(double x, double y, double z) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    set_camera_position(_viewer, x, y, z);
  }

  @override
  Future moveCameraToAsset(FilamentEntity entity) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    move_camera_to_asset(_viewer, entity);
  }

  @override
  Future setViewFrustumCulling(bool enabled) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    set_view_frustum_culling(_viewer, enabled);
  }

  @override
  Future setCameraExposure(
      double aperture, double shutterSpeed, double sensitivity) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    set_camera_exposure(_viewer, aperture, shutterSpeed, sensitivity);
  }

  @override
  Future setCameraRotation(double rads, double x, double y, double z) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    set_camera_rotation(_viewer, rads, x, y, z);
  }

  @override
  Future setCameraModelMatrix(List<double> matrix) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    assert(matrix.length == 16);
    var ptr = allocator<Float>(16);
    for (int i = 0; i < 16; i++) {
      ptr.elementAt(i).value = matrix[i];
    }
    set_camera_model_matrix(_viewer, ptr);
    allocator.free(ptr);
  }

  @override
  Future setMaterialColor(FilamentEntity entity, String meshName,
      int materialIndex, Color color) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    var result = set_material_color(
        _assetManager,
        entity,
        meshName.toNativeUtf8(allocator: allocator).cast<Char>(),
        materialIndex,
        color.red.toDouble() / 255.0,
        color.green.toDouble() / 255.0,
        color.blue.toDouble() / 255.0,
        color.alpha.toDouble() / 255.0);
    if (!result) {
      throw Exception("Failed to set material color");
    }
  }

  @override
  Future transformToUnitCube(FilamentEntity entity) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    transform_to_unit_cube(_assetManager, entity);
  }

  @override
  Future setPosition(
      FilamentEntity entity, double x, double y, double z) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    set_position(_assetManager, entity, x, y, z);
  }

  @override
  Future setScale(FilamentEntity entity, double scale) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    set_scale(_assetManager, entity, scale);
  }

  @override
  Future setRotation(
      FilamentEntity entity, double rads, double x, double y, double z) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    set_rotation(_assetManager, entity, rads, x, y, z);
  }

  @override
  Future hide(FilamentEntity entity, String meshName) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    if (hide_mesh(_assetManager, entity,
            meshName.toNativeUtf8(allocator: allocator).cast<Char>()) !=
        1) {}
  }

  @override
  Future reveal(FilamentEntity entity, String meshName) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    if (reveal_mesh(_assetManager, entity,
            meshName.toNativeUtf8(allocator: allocator).cast<Char>()) !=
        1) {
      throw Exception("Failed to reveal mesh $meshName");
    }
  }

  @override
  String? getNameForEntity(FilamentEntity entity) {
    final result = get_name_for_entity(_assetManager, entity);
    if (result == nullptr) {
      return null;
    }
    return result.cast<Utf8>().toDartString();
  }

  @override
  void pick(int x, int y) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available, ignoring");
    }
    final outPtr = allocator<EntityId>(1);
    outPtr.value = 0;

    pick_ffi(_viewer, x, textureDetails.value!.height - y, outPtr);
    int wait = 0;
    while (outPtr.value == 0) {
      await Future.delayed(const Duration(milliseconds: 32));
      wait++;
      if (wait > 10) {
        allocator.free(outPtr);
        throw Exception("Failed to get picking result");
      }
    }
    var entityId = outPtr.value;
    _pickResultController.add(entityId);
    allocator.free(outPtr);
  }

  @override
  Future<Matrix4> getCameraViewMatrix() async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available");
    }
    var arrayPtr = get_camera_view_matrix(_viewer);
    var viewMatrix = Matrix4.fromList(arrayPtr.asTypedList(16));
    flutter_filament_free(arrayPtr.cast<Void>());
    return viewMatrix;
  }

  @override
  Future<Matrix4> getCameraModelMatrix() async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available");
    }
    if (kIsWeb) {
      throw Exception("TODO");
    }
    var arrayPtr = get_camera_model_matrix(_viewer);
    var modelMatrix = Matrix4.fromList(arrayPtr.asTypedList(16));
    flutter_filament_free(arrayPtr.cast<Void>());
    return modelMatrix;
  }

  @override
  Future<Vector3> getCameraPosition() async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available");
    }
    var arrayPtr = get_camera_model_matrix(_viewer);

    Float64List doubleList = arrayPtr.asTypedList(16);

    var modelMatrix = Matrix4.fromFloat64List(doubleList);

    var position = modelMatrix.getColumn(3).xyz;

    flutter_filament_free(arrayPtr.cast<Void>());
    return position;
  }

  @override
  Future<Matrix3> getCameraRotation() async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available");
    }
    var arrayPtr = get_camera_model_matrix(_viewer);
    final doubleList = arrayPtr.asTypedList(16);

    var modelMatrix = Matrix4.fromFloat64List(doubleList);
    var rotationMatrix = Matrix3.identity();
    modelMatrix.copyRotation(rotationMatrix);
    flutter_filament_free(arrayPtr.cast<Void>());
    return rotationMatrix;
  }

  @override
  Future setCameraManipulatorOptions(
      {ManipulatorMode mode = ManipulatorMode.ORBIT,
      double orbitSpeedX = 0.01,
      double orbitSpeedY = 0.01,
      double zoomSpeed = 0.01}) async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available");
    }
    if (mode != ManipulatorMode.ORBIT) {
      throw Exception("Manipulator mode $mode not yet implemented");
    }
    set_camera_manipulator_options(
        _viewer, mode.index, orbitSpeedX, orbitSpeedX, zoomSpeed);
  }

  ///
  /// I don't think these two methods are accurate - don't rely on them, use the Frustum values instead.
  /// I think because we use [setLensProjection] and [setScaling] together, this projection matrix doesn't accurately reflect the field of view (because it's using an additional scaling matrix).
  /// Also, the near/far planes never seem to get updated (which is what I would expect to see when calling [getCameraCullingProjectionMatrix])
  ///
  @override
  Future<Matrix4> getCameraProjectionMatrix() async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available");
    }

    print(
        "WARNING: getCameraProjectionMatrix and getCameraCullingProjectionMatrix are not reliable. Consider these broken");

    var arrayPtr = get_camera_projection_matrix(_viewer);
    var doubleList = arrayPtr.asTypedList(16);
    var projectionMatrix = Matrix4.fromList(doubleList);
    flutter_filament_free(arrayPtr.cast<Void>());
    return projectionMatrix;
  }

  @override
  Future<Matrix4> getCameraCullingProjectionMatrix() async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available");
    }

    print(
        "WARNING: getCameraProjectionMatrix and getCameraCullingProjectionMatrix are not reliable. Consider these broken");
    var arrayPtr = get_camera_culling_projection_matrix(_viewer);
    var doubleList = arrayPtr.asTypedList(16);
    var projectionMatrix = Matrix4.fromList(doubleList);
    flutter_filament_free(arrayPtr.cast<Void>());
    return projectionMatrix;
  }

  @override
  Future<Frustum> getCameraFrustum() async {
    if (_viewer == nullptr) {
      throw Exception("No viewer available");
    }
    var arrayPtr = get_camera_frustum(_viewer);
    final doubleList = arrayPtr.asTypedList(24);

    var frustum = Frustum();
    frustum.plane0.setFromComponents(
        doubleList[0], doubleList[1], doubleList[2], doubleList[3]);
    frustum.plane1.setFromComponents(
        doubleList[4], doubleList[5], doubleList[6], doubleList[7]);
    frustum.plane2.setFromComponents(
        doubleList[8], doubleList[9], doubleList[10], doubleList[11]);
    frustum.plane3.setFromComponents(
        doubleList[12], doubleList[13], doubleList[14], doubleList[15]);
    frustum.plane4.setFromComponents(
        doubleList[16], doubleList[17], doubleList[18], doubleList[19]);
    frustum.plane5.setFromComponents(
        doubleList[20], doubleList[21], doubleList[22], doubleList[23]);
    flutter_filament_free(arrayPtr.cast<Void>());
    return frustum;
  }

  @override
  Future setBoneTransform(FilamentEntity entity, String meshName,
      String boneName, Matrix4 data) async {
    var ptr = allocator<Float>(16);
    for (int i = 0; i < 16; i++) {
      ptr.elementAt(i).value = data.storage[i];
    }

    var meshNamePtr = meshName.toNativeUtf8(allocator: allocator).cast<Char>();
    Pointer<Char> boneNamePtr =
        boneName.toNativeUtf8(allocator: allocator).cast<Char>();

    var result = set_bone_transform_ffi(
        _assetManager, entity, meshNamePtr, ptr, boneNamePtr);

    allocator.free(ptr);
    allocator.free(meshNamePtr);
    allocator.free(boneNamePtr);
    if (!result) {
      throw Exception("Failed to set bone transform. See logs for details");
    }
  }

  @override
  Future<FilamentEntity> getChildEntity(
      FilamentEntity parent, String childName) async {
    var childNamePtr =
        childName.toNativeUtf8(allocator: allocator).cast<Char>();
    try {
      var childEntity =
          find_child_entity_by_name(_assetManager, parent, childNamePtr);
      if (childEntity == _FILAMENT_ASSET_ERROR) {
        throw Exception(
            "Could not find child ${childName} under the specified entity");
      }
      return childEntity;
    } finally {
      allocator.free(childNamePtr);
    }
  }

  @override
  Future<List<String>> getMeshNames(FilamentEntity entity) async {
    var count = get_entity_count(_assetManager, entity, true);
    var names = <String>[];
    for (int i = 0; i < count; i++) {
      var name = get_entity_name_at(_assetManager, entity, i, true);
      if (name == nullptr) {
        throw Exception("Failed to find mesh at index $i");
      }
      names.add(name.cast<Utf8>().toDartString());
    }
    return names;
  }

  @override
  Future setRecording(bool recording) async {
    set_recording(_viewer, recording);
  }

  @override
  Future setRecordingOutputDirectory(String outputDir) async {
    var pathPtr = outputDir.toNativeUtf8(allocator: allocator);
    set_recording_output_directory(_viewer, pathPtr.cast<Char>());
    allocator.free(pathPtr);
  }
}
