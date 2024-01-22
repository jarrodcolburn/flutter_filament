#pragma once

#include <mutex>

#include <filament/Scene.h>

#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/ResourceLoader.h>

#include "SceneAsset.hpp"
#include "ResourceBuffer.hpp"

typedef int32_t EntityId;

namespace polyvox
{
    using namespace filament;
    using namespace filament::gltfio;

    class AssetManager
    {
    public:
        AssetManager(const ResourceLoaderWrapper *const loader,
                     NameComponentManager *ncm,
                     Engine *engine,
                     Scene *scene,
                     const char *uberArchivePath);
        ~AssetManager();
        EntityId loadGltf(const char *uri, const char *relativeResourcePath);
        EntityId loadGlb(const char *uri, bool unlit);
        FilamentAsset *getAssetByEntityId(EntityId entityId);
        void remove(EntityId entity);
        void destroyAll();
        unique_ptr<vector<string>> getAnimationNames(EntityId entity);
        float getAnimationDuration(EntityId entity, int animationIndex);
        unique_ptr<vector<string>> getMorphTargetNames(EntityId entity, const char *meshName);
        void transformToUnitCube(EntityId e);
        inline void updateTransform(EntityId e);
        void setScale(EntityId e, float scale);
        void setPosition(EntityId e, float x, float y, float z);
        void setRotation(EntityId e, float rads, float x, float y, float z);
        const utils::Entity *getCameraEntities(EntityId e);
        size_t getCameraEntityCount(EntityId e);
        const utils::Entity *getLightEntities(EntityId e) const noexcept;
        size_t getLightEntityCount(EntityId e) const noexcept;
        void updateAnimations();
        bool setMaterialColor(EntityId e, const char *meshName, int materialInstance, const float r, const float g, const float b, const float a);

        bool setMorphAnimationBuffer(
            EntityId entityId,
            const char *entityName,
            const float *const morphData,
            const int *const morphIndices,
            int numMorphTargets,
            int numFrames,
            float frameLengthInMs);

        void setMorphTargetWeights(EntityId entityId, const char *const entityName, const float *const weights, int count);

        /// @brief Set the local transform for the bone at boneIndex/skinIndex in the given entity.
        /// @param entityId the parent entity 
        /// @param entityName the name of the mesh under entityId for which the bone will be set.
        /// @param skinIndex the index of the joint skin. Currently only 0 is supported.
        /// @param boneName the name of the bone
        /// @param transform the 4x4 matrix representing the local transform for the bone
        /// @return true if the transform was successfully set, false otherwise
        bool setBoneTransform(EntityId entityId, const char *entityName, int skinIndex, const char* boneName, math::mat4f transform);

        /// @brief Set frame data to animate the given bones/entities.
        /// @param entity the parent entity
        /// @param frameData frame data as quaternions
        /// @param numFrames the number of frames
        /// @param boneName the name of the bone to animate
        /// @param meshName an array of mesh names under [entity] that should be animated
        /// @param numMeshTargets the number of meshes under [meshName] 
        /// @param frameLengthInMs the length of each frame in ms
        /// @return
        bool addBoneAnimation(
            EntityId entity,
            const float *const frameData,
            int numFrames,
            const char *const boneName,
            const char **const meshName,
            int numMeshTargets,
            float frameLengthInMs, 
            bool isModelSpace);
        void resetBones(EntityId entityId);
        void playAnimation(EntityId e, int index, bool loop, bool reverse, bool replaceActive, float crossfade = 0.3f);
        void stopAnimation(EntityId e, int index);
        void setMorphTargetWeights(const char *const entityName, float *weights, int count);
        void loadTexture(EntityId entity, const char *resourcePath, int renderableIndex);
        void setAnimationFrame(EntityId entity, int animationIndex, int animationFrame);
        bool hide(EntityId entity, const char *meshName);
        bool reveal(EntityId entity, const char *meshName);
        const char *getNameForEntity(EntityId entityId);
        utils::Entity findChildEntityByName(
            EntityId entityId,
            const char *entityName);
        int getEntityCount(EntityId entity, bool renderableOnly);
        const char* getEntityNameAt(EntityId entity, int index, bool renderableOnly);

    private:
        AssetLoader *_assetLoader = nullptr;
        const ResourceLoaderWrapper *const _resourceLoaderWrapper;
        NameComponentManager *_ncm = nullptr;
        Engine *_engine;
        Scene *_scene;
        MaterialProvider *_ubershaderProvider = nullptr;
        gltfio::ResourceLoader *_gltfResourceLoader = nullptr;
        gltfio::TextureProvider *_stbDecoder = nullptr;
        gltfio::TextureProvider *_ktxDecoder = nullptr;
        std::mutex _animationMutex;

        vector<SceneAsset> _assets;
        tsl::robin_map<EntityId, int> _entityIdLookup;

        utils::Entity findEntityByName(
            SceneAsset asset,
            const char *entityName);

        inline void updateTransform(SceneAsset &asset);

    };
}
