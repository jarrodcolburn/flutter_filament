// In order to *not* need this ignore, consider extracting the "web" version
// of your plugin as a separate package, instead of inlining it in the same
// package as the core of your plugin.
// ignore: avoid_web_libraries_in_flutter
import 'dart:html';
import 'dart:ui';
import 'dart:web_gl';
import 'package:wasm_ffi/wasm_ffi.dart';
import 'generated_bindings_web.dart';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// A web implementation of the FlutterFilamentPlatform of the FlutterFilament plugin.
class FlutterFilamentPluginWeb {
  // late html.CanvasElement _canvas;
  late RenderingContext _gl;
  DynamicLibrary _nativeLib;
  dynamic _texture;


  FlutterFilamentPluginWeb() {
    var canvas = document.querySelector('#drawHere') as CanvasElement;

    _gl = canvas.getContext("webgl") as RenderingContext;
    _texture = _gl.createTexture();
    _gl.bindTexture(WebGL.TEXTURE_2D, _texture);
    _gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MIN_FILTER, WebGL.LINEAR);
    _gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MAG_FILTER, WebGL.LINEAR);
    _gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_MAG_FILTER, WebGL.LINEAR);
    _gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_WRAP_S, WebGL.CLAMP_TO_EDGE);
    _gl.texParameteri(WebGL.TEXTURE_2D, WebGL.TEXTURE_WRAP_T, WebGL.CLAMP_TO_EDGE);
    
    _gl.clearColor(.1, .2, .3, 1.0);
    _gl.clear(WebGL.COLOR_BUFFER_BIT);

    _nativeLib = DynamicLibrary.open('libopus.so');

    // _gl.texImage2D(
    //     WebGL.TEXTURE_2D,
    //     0,
    //     WebGL.RGBA8,
    //     canvas.width ?? 100,
    //     canvas.height ?? 100,
    //     0,
    //     WebGL.RGBA,
    //     WebGL.UNSIGNED_BYTE,
    //     Uint8List.fromList([255, 0, 0, 255]));
  }
  static void registerWith(Registrar registrar) {
    final MethodChannel channel = MethodChannel("app.polyvox.filament/event",
        const StandardMethodCodec(), registrar.messenger);
    final FlutterFilamentPluginWeb instance = FlutterFilamentPluginWeb();
    channel.setMethodCallHandler(instance.handleMethodCall);
  }

  Future handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case "createTexture":
        return [0,null, _texture, null];
      case "destroyTexture":
        return true;
  }
  }