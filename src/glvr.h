#ifndef GLVR_H
#define GLVR_H

#ifdef __cplusplus
extern "C" {
#endif

enum {
  KEY_0,
  KEY_1,
  KEY_2,
  KEY_3,
  KEY_4,
  KEY_5,
  KEY_6,
  KEY_7,
  KEY_8,
  KEY_9,

  KEY_F1,
  KEY_F2,
  KEY_F3,
  KEY_F4,
  KEY_F5,
  KEY_F6,
  KEY_F7,
  KEY_F8,
  KEY_F9,
  KEY_F10,
  KEY_F11,
  KEY_F12,

  KEY_A,
  KEY_B,
  KEY_C,
  KEY_D,
  KEY_E,
  KEY_F,
  KEY_G,
  KEY_H,
  KEY_I,
  KEY_J,
  KEY_K,
  KEY_L,
  KEY_M,
  KEY_N,
  KEY_O,
  KEY_P,
  KEY_Q,
  KEY_R,
  KEY_S,
  KEY_T,
  KEY_U,
  KEY_V,
  KEY_W,
  KEY_X,
  KEY_Y,
  KEY_Z,

  KEY_DOWN,
  KEY_LEFT,
  KEY_RIGHT,
  KEY_UP,

  KEY_BACKSPACE,
  KEY_DELETE,
  KEY_END,
  KEY_ESCAPE,
  KEY_HOME,
  KEY_INSERT,
  KEY_PAGE_DOWN,
  KEY_PAGE_UP,
  KEY_PAUSE,
  KEY_RETURN,
  KEY_SPACE,
  KEY_TAB,

  KEYS_COUNT
};

typedef struct {
  int width;
  int height;
  unsigned int texture;
} glvr_setup_t;

typedef struct {
  float deltaX, deltaY;
} glvr_mouse_t;

typedef struct {
  int index; // 0 for left, 1 for right
  float fov[4]; // left, right, up, down
  float translation[3]; // x, y, z
  float rotation[4]; // x, y, z, w
  float modelview[16]; // translation and rotation
  float projection[16]; // fov
  int viewport[4]; // x, y, w, h
} glvr_eye_t;

void glvrSetSetupCallback(void (*callback)(glvr_setup_t *setup));
void glvrSetUpdateCallback(void (*callback)(float seconds));
void glvrSetRenderCallback(void (*callback)(glvr_eye_t *eye));
void glvrSetKeyboardCallback(void (*callback)(int key, int down));

void glvrRun();
glvr_mouse_t glvrGetMouseInfo();
int glvrIsKeyDown(int key);

#ifdef __cplusplus
}
#endif

#include <OpenGL/gl.h>

#endif
