
#include "FlutterFilamentFFIApi.h"

#include "FilamentViewer.hpp"
#include "Log.hpp"
#include "ThreadPool.hpp"
#include "filament/LightManager.h"

#include <functional>
#include <mutex>
#include <thread>
#include <stdlib.h>

#include <emscripten/emscripten.h>
#include <emscripten/html5.h>
#include <emscripten/threading.h>
#include <emscripten/val.h>
#define GL_GLEXT_PROTOTYPES
#include <GL/gl.h>
#include <GL/glext.h>

#include <emscripten/emscripten.h>
#include <emscripten/html5.h>
#include <emscripten/threading.h>
#include <emscripten/val.h>

#include <pthread.h>

using namespace polyvox;

class RenderLoop {
public:
  explicit RenderLoop() {
    _t = new std::thread([this]() {
      while (!_stop) {
        {
          if (_rendering) {
            doRender();
          }
        }
        std::function<void()> task;
        {
          std::unique_lock<std::mutex> lock(_access);
          if (_tasks.empty()) {
            _cond.wait_for(lock, std::chrono::duration<float, std::milli>(
                                     _frameIntervalInMilliseconds));
            continue;
          }
          task = std::move(_tasks.front());
          _tasks.pop_front();
        }
        task();
      }
    });
  }
  ~RenderLoop() {
    _stop = true;
    _t->join();
  }


  void* createViewer(void *const context, void *const platform,
                           const char *uberArchivePath,
                           const ResourceLoaderWrapper *const loader,
                           void (*renderCallback)(void *), void *const renderCallbackOwner, void** out) {
    // emscripten_pause_main_loop();

    _renderCallback = renderCallback;
    _renderCallbackOwner = renderCallbackOwner;
    std::cout << "Creating viewer" << std::endl;
    pthread_t flutter_thread_id = pthread_self();
    printf("Flutter thread  %p\n", flutter_thread_id);
    std::packaged_task<FilamentViewer *()> lambda([&]() mutable {
      std::thread::id this_id = std::this_thread::get_id();

      pthread_t filament_runner_thread_id = pthread_self();
      printf("filament runner thread  %p\n", filament_runner_thread_id);
   
      //  EmscriptenWebGLContextAttributes attr;
      //  emscripten_webgl_init_context_attributes(&attr);
      //  attr.explicitSwapControl = EM_FALSE;
      //  attr.proxyContextToMainThread = EMSCRIPTEN_WEBGL_CONTEXT_PROXY_ALWAYS;
      //  attr.renderViaOffscreenBackBuffer = EM_TRUE;
      //  attr.majorVersion = 2;  
    
      //  auto newContext = emscripten_webgl_create_context("#canvas", &attr);
      //   std::cout << "created context  " << newContext << " with major/minor ver " << attr.majorVersion << " " << attr.minorVersion << std::endl;
      auto success = emscripten_webgl_make_context_current((EMSCRIPTEN_WEBGL_CONTEXT_HANDLE)context);
      if(success != EMSCRIPTEN_RESULT_SUCCESS) {
        std::cout << "failed to make context current  " << std::endl;
        // return nullptr;
      }
      std::cout << "made current" << std::endl;
      glClearColor(1.0f, 1.0f, 0.0f, 1.0f);
      glClear(GL_COLOR_BUFFER_BIT);
   
    
      // success = emscripten_webgl_make_context_current((EMSCRIPTEN_WEBGL_CONTEXT_HANDLE)NULL);
       viewer = new FilamentViewer((void*)context, loader, platform, uberArchivePath);
       *out = viewer;
      return viewer;
    });
    auto fut = add_task(lambda);
    // if(!out) {
      fut.wait();
    // }
    return viewer;
  }

  void destroyViewer() {
    std::packaged_task<void()> lambda([&]() mutable {
      _rendering = false;
      destroy_filament_viewer(viewer);
      viewer = nullptr;
    });
    auto fut = add_task(lambda);
    fut.wait();
  }

  void setRendering(bool rendering) {
    std::packaged_task<void()> lambda(
        [&]() mutable { this->_rendering = rendering; });
    auto fut = add_task(lambda);
    // fut.wait();
  }

  void doRender() {
    render(viewer, 0, nullptr, nullptr, nullptr);
    emscripten_webgl_commit_frame();
    // if(_renderCallback) {
    //   _renderCallback(_renderCallbackOwner);
    // }
  }

  void setFrameIntervalInMilliseconds(float frameIntervalInMilliseconds) {
    _frameIntervalInMilliseconds = frameIntervalInMilliseconds;
  }

  template <class Rt>
  auto add_task(std::packaged_task<Rt()> &pt) -> std::future<Rt> {
    std::unique_lock<std::mutex> lock(_access);
    auto ret = pt.get_future();
    _tasks.push_back([pt = std::make_shared<std::packaged_task<Rt()>>(
                          std::move(pt))] { (*pt)(); });
    _cond.notify_one();
    return ret;
  }
  FilamentViewer *viewer = nullptr;

private:
  bool _stop = false;
  bool _rendering = false;
  float _frameIntervalInMilliseconds = 1000.0 / 60.0;
  std::mutex _access;

  void (*_renderCallback)(void *const) = nullptr;
  void *_renderCallbackOwner = nullptr;
  std::thread *_t = nullptr;
  std::condition_variable _cond;
  std::deque<std::function<void()>> _tasks;
};

extern "C" {

static RenderLoop *_rl;
static void* _context;

FLUTTER_PLUGIN_EXPORT void* create_filament_viewer_ffi(
    void *const context, void *const platform, const char *uberArchivePath,
    const ResourceLoaderWrapper *const loader,
    void (*renderCallback)(void *const renderCallbackOwner),
    void *const renderCallbackOwner, void** out) {

    _context = context;
  if (!_rl) {
    _rl = new RenderLoop();
  }
  return _rl->createViewer(context, platform, uberArchivePath, loader,
                           renderCallback, renderCallbackOwner, out);
}

FLUTTER_PLUGIN_EXPORT void destroy_filament_viewer_ffi(void *const viewer) {
  _rl->destroyViewer();
}

FLUTTER_PLUGIN_EXPORT void create_swap_chain_ffi(void *const viewer,
                                                 void *const surface,
                                                 uint32_t width,
                                                 uint32_t height) {
  Log("Creating swapchain %dx%d with viewer %p and surface %p", width, height, viewer, surface);
  std::packaged_task<void()> lambda(
      [&]() mutable { 
        create_swap_chain(viewer, surface, width, height); 
          Log("swapchain cerate finisehd");

        });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void destroy_swap_chain_ffi(void *const viewer) {
  Log("Destroying swapchain");
  std::packaged_task<void()> lambda(
      [&]() mutable { 
        destroy_swap_chain(viewer); 
    });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void create_render_target_ffi(void *const viewer,
                                                    intptr_t nativeTextureId,
                                                    uint32_t width,
                                                    uint32_t height) {
  std::packaged_task<void()> lambda([&]() mutable {
    create_render_target(viewer, nativeTextureId, width, height);
  });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void update_viewport_and_camera_projection_ffi(
    void *const viewer, const uint32_t width, const uint32_t height,
    const float scaleFactor) {
  Log("Update viewport  %dx%d", width, height);
  std::packaged_task<void()> lambda([&]() mutable {
    update_viewport_and_camera_projection(viewer, width, height, scaleFactor);
      Log("Update viewport finished", width, height);

  });
  auto fut = _rl->add_task(lambda);
  // fut.wait();
}

FLUTTER_PLUGIN_EXPORT void set_rendering_ffi(void *const viewer,
                                             bool rendering) {
  if (!_rl) {
    Log("No render loop!"); // PANIC?
  } else {
    if (rendering) {
      Log("Set rendering to true");
    } else {
      Log("Set rendering to false");
    }
    _rl->setRendering(rendering);
  }
}

FLUTTER_PLUGIN_EXPORT void
set_frame_interval_ffi(float frameIntervalInMilliseconds) {
  _rl->setFrameIntervalInMilliseconds(frameIntervalInMilliseconds);
}


EM_BOOL foo(double time, void* userData) {
  // auto success = emscripten_webgl_make_context_current((EMSCRIPTEN_WEBGL_CONTEXT_HANDLE)_context);
  // if(success != EMSCRIPTEN_RESULT_SUCCESS) {
  //   std::cout << "failed to make context current  " << std::endl;
  //   return EM_FALSE;
  // }
  // // ((RenderLoop*)userData)->doRender();
  // float r = float(rand()) / float(RAND_MAX);
  // float g = float(rand()) / float(RAND_MAX);
  // float b = float(rand()) / float(RAND_MAX);
  // glClearColor(r, g, b, 1.0f);
  // glClear(GL_COLOR_BUFFER_BIT); 
  emscripten_webgl_commit_frame();
  return EM_TRUE;
}

FLUTTER_PLUGIN_EXPORT void render_ffi(void *const viewer) {
    std::cout << "render ffi" << std::endl;

  std::packaged_task<void()> lambda([&]() mutable { 
    std::cout << "doing render" << std::endl;
    _rl->doRender(); 
    emscripten_request_animation_frame(foo, nullptr);
  });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void
set_background_color_ffi(void *const viewer, const float r, const float g,
                         const float b, const float a) {
  std::packaged_task<void()> lambda(
      [&]() mutable { set_background_color(viewer, r, g, b, a); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT EntityId load_gltf_ffi(void *const assetManager,
                                             const char *path,
                                             const char *relativeResourcePath) {
  std::packaged_task<EntityId()> lambda([&]() mutable {
    return load_gltf(assetManager, path, relativeResourcePath);
  });
  auto fut = _rl->add_task(lambda);
  fut.wait();
  return fut.get();
}

FLUTTER_PLUGIN_EXPORT EntityId load_glb_ffi(void *const assetManager,
                                            const char *path, bool unlit) {
  std::packaged_task<EntityId()> lambda(
      [&]() mutable { return load_glb(assetManager, path, unlit); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
  return fut.get();
}

FLUTTER_PLUGIN_EXPORT void clear_background_image_ffi(void *const viewer) {
  std::packaged_task<void()> lambda([&] { clear_background_image(viewer); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void set_background_image_ffi(void *const viewer,
                                                    const char *path,
                                                    bool fillHeight) {
  std::packaged_task<void()> lambda(
      [&] { set_background_image(viewer, path, fillHeight); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}
FLUTTER_PLUGIN_EXPORT void set_background_image_position_ffi(void *const viewer,
                                                             float x, float y,
                                                             bool clamp) {
  std::packaged_task<void()> lambda(
      [&] { set_background_image_position(viewer, x, y, clamp); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}
FLUTTER_PLUGIN_EXPORT void set_tone_mapping_ffi(void *const viewer,
                                                int toneMapping) {
  std::packaged_task<void()> lambda(
      [&] { set_tone_mapping(viewer, toneMapping); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}
FLUTTER_PLUGIN_EXPORT void set_bloom_ffi(void *const viewer, float strength) {
  std::packaged_task<void()> lambda([&] { set_bloom(viewer, strength); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void load_skybox_ffi(void *const viewer,
                                           const char *skyboxPath) {  
  // emscripten_request_animation_frame_loop(foo, _rl);                                                
  std::packaged_task<void()> lambda([&] {    

  //   auto success = emscripten_webgl_make_context_current((EMSCRIPTEN_WEBGL_CONTEXT_HANDLE)_context);
  // if(success != EMSCRIPTEN_RESULT_SUCCESS) {
  //   std::cout << "failed to make context current  " << std::endl;
  //   // return EM_FALSE;
  // }
  // // ((RenderLoop*)userData)->doRender();
  // float r = float(rand()) / float(RAND_MAX);
  // float g = float(rand()) / float(RAND_MAX);
  // float b = float(rand()) / float(RAND_MAX);
  // glClearColor(r, g, b, 1.0f);
  // glClear(GL_COLOR_BUFFER_BIT); 
    
    load_skybox(_rl->viewer, skyboxPath); 
    std::cout << "doing render" << std::endl;
    _rl->doRender();
    std::cout << "requesting animation frame" << std::endl;
    
    emscripten_webgl_commit_frame();
    });
  auto fut = _rl->add_task(lambda);
  // fut.wait();
}
FLUTTER_PLUGIN_EXPORT void load_ibl_ffi(void *const viewer, const char *iblPath,
                                        float intensity) {
  std::packaged_task<void()> lambda(
      [&] { load_ibl(viewer, iblPath, intensity); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}
FLUTTER_PLUGIN_EXPORT void remove_skybox_ffi(void *const viewer) {
  std::packaged_task<void()> lambda([&] { remove_skybox(viewer); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void remove_ibl_ffi(void *const viewer) {
  std::packaged_task<void()> lambda([&] { remove_ibl(viewer); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

EntityId add_light_ffi(void *const viewer, uint8_t type, float colour,
                       float intensity, float posX, float posY, float posZ,
                       float dirX, float dirY, float dirZ, bool shadows) {
  std::packaged_task<EntityId()> lambda([&] {
    return add_light(viewer, type, colour, intensity, posX, posY, posZ, dirX,
                     dirY, dirZ, shadows);
  });
  auto fut = _rl->add_task(lambda);
  fut.wait();
  return fut.get();
}

FLUTTER_PLUGIN_EXPORT void remove_light_ffi(void *const viewer,
                                            EntityId entityId) {
  std::packaged_task<void()> lambda([&] { remove_light(viewer, entityId); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void clear_lights_ffi(void *const viewer) {
  std::packaged_task<void()> lambda([&] { clear_lights(viewer); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void remove_asset_ffi(void *const viewer,
                                            EntityId asset) {
  std::packaged_task<void()> lambda([&] { remove_asset(viewer, asset); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}
FLUTTER_PLUGIN_EXPORT void clear_assets_ffi(void *const viewer) {
  std::packaged_task<void()> lambda([&] { clear_assets(viewer); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT bool set_camera_ffi(void *const viewer, EntityId asset,
                                          const char *nodeName) {
  std::packaged_task<bool()> lambda(
      [&] { return set_camera(viewer, asset, nodeName); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
  return fut.get();
}

FLUTTER_PLUGIN_EXPORT void set_bone_animation_ffi(
    void *assetManager, EntityId asset, const float *const frameData,
    int numFrames, int numBones, const char **const boneNames,
    const char **const meshName, int numMeshTargets, float frameLengthInMs) {
  std::packaged_task<void()> lambda([&] {
    set_bone_animation(assetManager, asset, frameData, numFrames, numBones,
                       boneNames, meshName, numMeshTargets, frameLengthInMs);
  });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void
get_morph_target_name_ffi(void *assetManager, EntityId asset,
                          const char *meshName, char *const outPtr, int index) {
  std::packaged_task<void()> lambda([&] {
    get_morph_target_name(assetManager, asset, meshName, outPtr, index);
  });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT int
get_morph_target_name_count_ffi(void *assetManager, EntityId asset,
                                const char *meshName) {
  std::packaged_task<int()> lambda([&] {
    return get_morph_target_name_count(assetManager, asset, meshName);
  });
  auto fut = _rl->add_task(lambda);
  fut.wait();
  return fut.get();
}

void set_morph_target_weights_ffi(void *const assetManager, EntityId asset,
                                  const char *const entityName,
                                  const float *const morphData,
                                  int numWeights) {
  // TODO
}

FLUTTER_PLUGIN_EXPORT void play_animation_ffi(void *const assetManager,
                                              EntityId asset, int index,
                                              bool loop, bool reverse,
                                              bool replaceActive,
                                              float crossfade) {
  std::packaged_task<void()> lambda([&] {
    play_animation(assetManager, asset, index, loop, reverse, replaceActive,
                   crossfade);
  });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void set_animation_frame_ffi(void *const assetManager,
                                                   EntityId asset,
                                                   int animationIndex,
                                                   int animationFrame) {
  std::packaged_task<void()> lambda([&] {
    set_animation_frame(assetManager, asset, animationIndex, animationFrame);
  });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void stop_animation_ffi(void *const assetManager,
                                              EntityId asset, int index) {
  std::packaged_task<void()> lambda(
      [&] { stop_animation(assetManager, asset, index); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT int get_animation_count_ffi(void *const assetManager,
                                                  EntityId asset) {
  std::packaged_task<int()> lambda(
      [&] { return get_animation_count(assetManager, asset); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
  return fut.get();
}
FLUTTER_PLUGIN_EXPORT void get_animation_name_ffi(void *const assetManager,
                                                  EntityId asset,
                                                  char *const outPtr,
                                                  int index) {
  std::packaged_task<void()> lambda(
      [&] { get_animation_name(assetManager, asset, outPtr, index); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void set_post_processing_ffi(void *const viewer,
                                                   bool enabled) {
  std::packaged_task<void()> lambda(
      [&] { set_post_processing(viewer, enabled); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT void pick_ffi(void *const viewer, int x, int y,
                                    EntityId *entityId) {
  std::packaged_task<void()> lambda([&] { pick(viewer, x, y, entityId); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
}

FLUTTER_PLUGIN_EXPORT const char *
get_name_for_entity_ffi(void *const assetManager, const EntityId entityId) {
  std::packaged_task<const char *()> lambda(
      [&] { return get_name_for_entity(assetManager, entityId); });
  auto fut = _rl->add_task(lambda);
  fut.wait();
  return fut.get();
}

FLUTTER_PLUGIN_EXPORT void ios_dummy_ffi() { Log("Dummy called"); }
}
