#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d11.lib")

#include "flutter_filament_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <flutter/texture_registrar.h>

#include <codecvt>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <future>
#include <iostream>
#include <locale>
#include <map>
#include <math.h>
#include <memory>
#include <sstream>
#include <string>
#include <vector>
#include <thread>

#include "FlutterFilamentApi.h"

#include <Commctrl.h>
#include <Windows.h>
#include <dwmapi.h>
#include <wrl.h>

#include "flutter_render_context.h"

#if USE_ANGLE
#include "egl_context.h"
#else
#include "wgl_context.h"
#endif

namespace flutter_filament {

  using namespace std::chrono_literals;


void FlutterFilamentPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "app.polyvox.filament/event",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterFilamentPlugin>(
      registrar->texture_registrar(), registrar, channel);

  registrar->AddPlugin(std::move(plugin));
}

FlutterFilamentPlugin::FlutterFilamentPlugin(
    flutter::TextureRegistrar *textureRegistrar,
    flutter::PluginRegistrarWindows *pluginRegistrar,
    std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> &channel)
    : _textureRegistrar(textureRegistrar), _pluginRegistrar(pluginRegistrar),
      _channel(std::move(channel)) {

  // attach the method call handler for incoming messages
  _channel->SetMethodCallHandler([=](const auto &call, auto result) {
    std::cout << call.method_name() << std::endl;
    this->HandleMethodCall(call, std::move(result));
  });
}


FlutterFilamentPlugin::~FlutterFilamentPlugin() {}

ResourceBuffer FlutterFilamentPlugin::loadResource(const char *name) {

  std::string name_str(name);
  std::filesystem::path targetFilePath;

  if (name_str.rfind("file://", 0) == 0) {
    targetFilePath = name_str.substr(7);
  } else {

    if (name_str.rfind("asset://", 0) == 0) {
      name_str = name_str.substr(8);
    }

    TCHAR pBuf[512];
    size_t len = sizeof(pBuf);
    int bytes = GetModuleFileName(NULL, pBuf, len);
    std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;
    std::wstring assetPath = converter.from_bytes(name_str.c_str());

    std::wstring exePathBuf(pBuf);
    std::filesystem::path exePath(exePathBuf);
    auto exeDir = exePath.remove_filename();
    targetFilePath = exeDir.wstring() + L"data/flutter_assets/" + assetPath;
  }
  std::streampos length;

  std::ifstream is(targetFilePath.c_str(), std::ios::binary);
  if (!is) {
    std::cout << "Failed to find resource at file path " << targetFilePath
              << std::endl;
    return ResourceBuffer(nullptr, 0, -1);
  }
  is.seekg(0, std::ios::end);
  length = is.tellg();

  char *buffer;
  buffer = new char[length];
  is.seekg(0, std::ios::beg);
  is.read(buffer, length);
  is.close();
  auto id = _resources.size();
  auto rb = ResourceBuffer(buffer, length, id);
  _resources.emplace(id, rb);

  std::wcout << "Loaded resource of length " << length << " from path "
             << targetFilePath << std::endl;

  return rb;
}

void FlutterFilamentPlugin::freeResource(ResourceBuffer rbuf) {
  free((void *)rbuf.data);
}

static ResourceBuffer _loadResource(const char *path, void *const plugin) {
  return ((FlutterFilamentPlugin *)plugin)->loadResource(path);
}

static void _freeResource(ResourceBuffer rbf, void *const plugin) {
  ((FlutterFilamentPlugin *)plugin)->freeResource(rbf);
}

// this is the C-style function that will be returned via getRenderCallback
// called on every frame by the FFI API
// this is just a convenient wrapper to call RenderCallback on the actual plugin
// instance
void render_callback(void *owner) {
  ((FlutterFilamentPlugin *)owner)->RenderCallback();
}

// this is the method on FlutterFilamentPlugin that will copy between D3D
// textures
void FlutterFilamentPlugin::RenderCallback() {
  if (_context) {
      auto flutterTextureId = _context->GetFlutterTextureId();
#ifdef USE_ANGLE
    _active->RenderCallback();
#endif
#if !WGL_USE_BACKING_WINDOW
    _textureRegistrar->MarkTextureFrameAvailable(flutterTextureId);
#endif
  }
}

void FlutterFilamentPlugin::CreateTexture(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());

  double dWidth = *(std::get_if<double>(&(args->at(0))));
  double dHeight = *(std::get_if<double>(&(args->at(1))));
  double dLeft = *(std::get_if<double>(&(args->at(2))));
  double dTop = *(std::get_if<double>(&(args->at(3))));
  auto width = (uint32_t)round(dWidth );
  auto height = (uint32_t)round(dHeight );
  auto left = (uint32_t)round(dLeft );
  auto top = (uint32_t)round(dTop );

  std::cout << "Using " << width << "x" << height << std::endl;
  
  // create a single shared context for the life of the application
  // this will be used to create a backing texture and passed to Filament
  if (!_context) {
#ifdef USE_ANGLE
    _context = std::make_unique<EGLContext>(_pluginRegistrar);
#else
    _context = std::make_unique<WGLContext>(_pluginRegistrar, _textureRegistrar);
#endif
  }
  _context->CreateRenderingSurface(width, height, std::move(result), left, top);
}

void FlutterFilamentPlugin::DestroyTexture(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {


  const auto *flutterTextureId = std::get_if<int64_t>(methodCall.arguments());

  if (!flutterTextureId) {
    result->Error("NOT_IMPLEMENTED", "Flutter texture ID must be provided");
    return;
  }
  
  if (_context) {
      _context->DestroyTexture(std::move(result));
  }
  else {
      result->Error("NO_CONTEXT", "No rendering context is active");
  }

}

void FlutterFilamentPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &methodCall,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  if (methodCall.method_name() == "usesBackingWindow") {
    result->Success(flutter::EncodableValue(
      #ifdef WGL_USE_BACKING_WINDOW
      true
      #else
      false
      #endif
    ));
  } else if (methodCall.method_name() == "getResourceLoaderWrapper") {
    const ResourceLoaderWrapper *const resourceLoader =
        new ResourceLoaderWrapper(_loadResource, _freeResource, this);
    result->Success(flutter::EncodableValue((int64_t)resourceLoader));
  } else if (methodCall.method_name() == "resizeWindow") {
    #if WGL_USE_BACKING_WINDOW
      const auto *args =
      std::get_if<flutter::EncodableList>(methodCall.arguments());
      double dWidth = *(std::get_if<double>(&(args->at(0))));
      double dHeight = *(std::get_if<double>(&(args->at(1))));
      double dLeft = *(std::get_if<double>(&(args->at(2))));
      double dTop = *(std::get_if<double>(&(args->at(3))));
      auto width = (uint32_t)round(dWidth );
      auto height = (uint32_t)round(dHeight );
      auto left = (uint32_t)round(dLeft );
      auto top = (uint32_t)round(dTop );
      _context->ResizeRenderingSurface(width, height, left, top);
      result->Success();
    #else
      result->Error("ERROR", "resizeWindow is only available when using a backing window");
    #endif
  } else if (methodCall.method_name() == "createTexture") {
    CreateTexture(methodCall, std::move(result));
  } else if (methodCall.method_name() == "destroyTexture") {
    DestroyTexture(methodCall, std::move(result));
  } else if (methodCall.method_name() == "getRenderCallback") {
    flutter::EncodableList resultList;
    #if !ANGLE && WGL_USE_BACKING_WINDOW
        resultList.push_back(flutter::EncodableValue((int64_t)nullptr));
        resultList.push_back(flutter::EncodableValue((int64_t)nullptr));
    #else
        resultList.push_back(flutter::EncodableValue((int64_t)&render_callback));
        resultList.push_back(flutter::EncodableValue((int64_t)this));
    #endif
    result->Success(resultList);
  } else if (methodCall.method_name() == "getDriverPlatform") {
#ifdef USE_ANGLE
    result->Success(flutter::EncodableValue((int64_t)_platform));
#else
    result->Success(flutter::EncodableValue((int64_t) nullptr));
#endif
  } else {
    result->Error("NOT_IMPLEMENTED", "Method is not implemented %s",
                  methodCall.method_name());
  }
}

} // namespace flutter_filament
