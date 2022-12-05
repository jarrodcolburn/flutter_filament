#ifndef IMAGE_MATERIAL_H_
#define IMAGE_MATERIAL_H_

#include <stdint.h>

extern "C" {
    extern const uint8_t IMAGE_MATERIAL_PACKAGE[];
    extern int IMAGE_MATERIAL_IMAGE_OFFSET;
    extern int IMAGE_MATERIAL_IMAGE_SIZE;
}
#define IMAGE_MATERIAL_IMAGE_DATA (IMAGE_MATERIAL_PACKAGE + IMAGE_MATERIAL_IMAGE_OFFSET)

#endif
