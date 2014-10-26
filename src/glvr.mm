#include "glvr.h"
#import <Cocoa/Cocoa.h>
#import <mach/mach_time.h>

#define OVR_OS_MAC
#include "OVR_CAPI.h"
#include "OVR_CAPI_GL.h"
#include "OVR_Math.h"

@class View;

static ovrHmd HMD;
static ovrGLTexture eyeTextures[2];
static ovrEyeRenderDesc eyeRenderDesc[2];

static NSApplication *application;
static NSWindow *window;
static View *view;

static bool mouseLock;
static bool keys[KEYS_COUNT];
static glvr_mouse_t mouseInfo;
static uint64_t oldTime;
static mach_timebase_info_data_t timeInfo;

static void (*setupCallback)(glvr_setup_t *setup);
static void (*updateCallback)(float seconds);
static void (*renderCallback)(glvr_eye_t *eye);
static void (*keyboardCallback)(int key, int down);

static int displayFromScreen(NSScreen *screen) {
  return [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] longValue];
}

static int decodeKey(NSEvent *event) {
  NSString *characters = [event charactersIgnoringModifiers];

  if ([characters length] < 1) {
    return -1;
  }

  switch ([characters characterAtIndex:0]) {
    case '0': return KEY_0;
    case '1': return KEY_1;
    case '2': return KEY_2;
    case '3': return KEY_3;
    case '4': return KEY_4;
    case '5': return KEY_5;
    case '6': return KEY_6;
    case '7': return KEY_7;
    case '8': return KEY_8;
    case '9': return KEY_9;

    case NSF1FunctionKey: return KEY_F1;
    case NSF2FunctionKey: return KEY_F2;
    case NSF3FunctionKey: return KEY_F3;
    case NSF4FunctionKey: return KEY_F4;
    case NSF5FunctionKey: return KEY_F5;
    case NSF6FunctionKey: return KEY_F6;
    case NSF7FunctionKey: return KEY_F7;
    case NSF8FunctionKey: return KEY_F8;
    case NSF9FunctionKey: return KEY_F9;
    case NSF10FunctionKey: return KEY_F10;
    case NSF11FunctionKey: return KEY_F11;
    case NSF12FunctionKey: return KEY_F12;

    case 'a': return KEY_A;
    case 'b': return KEY_B;
    case 'c': return KEY_C;
    case 'd': return KEY_D;
    case 'e': return KEY_E;
    case 'f': return KEY_F;
    case 'g': return KEY_G;
    case 'h': return KEY_H;
    case 'i': return KEY_I;
    case 'j': return KEY_J;
    case 'k': return KEY_K;
    case 'l': return KEY_L;
    case 'm': return KEY_M;
    case 'n': return KEY_N;
    case 'o': return KEY_O;
    case 'p': return KEY_P;
    case 'q': return KEY_Q;
    case 'r': return KEY_R;
    case 's': return KEY_S;
    case 't': return KEY_T;
    case 'u': return KEY_U;
    case 'v': return KEY_V;
    case 'w': return KEY_W;
    case 'x': return KEY_X;
    case 'y': return KEY_Y;
    case 'z': return KEY_Z;

    case NSDownArrowFunctionKey: return KEY_DOWN;
    case NSLeftArrowFunctionKey: return KEY_LEFT;
    case NSRightArrowFunctionKey: return KEY_RIGHT;
    case NSUpArrowFunctionKey: return KEY_UP;

    case 127: return KEY_BACKSPACE;
    case NSDeleteFunctionKey: return KEY_DELETE;
    case NSEndFunctionKey: return KEY_END;
    case 27: return KEY_ESCAPE;
    case NSHomeFunctionKey: return KEY_HOME;
    case NSInsertFunctionKey: return KEY_INSERT;
    case NSPageDownFunctionKey: return KEY_PAGE_DOWN;
    case NSPageUpFunctionKey: return KEY_PAGE_UP;
    case NSPauseFunctionKey: return KEY_PAUSE;
    case '\n': return KEY_RETURN;
    case ' ': return KEY_SPACE;
    case '\t': return KEY_TAB;
  }

  return -1;
}

@interface View : NSOpenGLView <NSWindowDelegate>
@end

@implementation View

- (id)initWithFrame:(NSRect)frame {
  NSOpenGLPixelFormatAttribute attributes[] = {
    NSOpenGLPFADoubleBuffer,
    NSOpenGLPFADepthSize, 24,
    NSOpenGLPFAStencilSize, 8,
    0
  };
  NSOpenGLPixelFormat *format = [[[NSOpenGLPixelFormat alloc] initWithAttributes:attributes] autorelease];
  self = [super initWithFrame:frame pixelFormat:format];
  return self;
}

- (void)prepareOpenGL {
  int swap = 0;
  [[self openGLContext] makeCurrentContext];
  [[self openGLContext] setValues:&swap forParameter:NSOpenGLCPSwapInterval];

  mach_timebase_info(&timeInfo);
  oldTime = mach_absolute_time();

  ovrSizei recommendedLeftSize = ovrHmd_GetFovTextureSize(HMD, ovrEye_Left, HMD->DefaultEyeFov[0], 1);
  ovrSizei recommendedRightSize = ovrHmd_GetFovTextureSize(HMD, ovrEye_Right, HMD->DefaultEyeFov[1], 1);
  int width = recommendedLeftSize.w + recommendedRightSize.w;
  int height = MAX(recommendedLeftSize.h, recommendedRightSize.h);

  GLuint texture = 0;
  glGenTextures(1, &texture);
  glBindTexture(GL_TEXTURE_2D, texture);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
  glBindTexture(GL_TEXTURE_2D, 0);

  eyeTextures[ovrEye_Left].OGL.Header.API = ovrRenderAPI_OpenGL;
  eyeTextures[ovrEye_Left].OGL.TexId = texture;
  eyeTextures[ovrEye_Left].OGL.Header.TextureSize = { width, height };
  eyeTextures[ovrEye_Left].OGL.Header.RenderViewport = { { 0, 0 }, { width / 2, height } };
  eyeTextures[ovrEye_Right] = eyeTextures[ovrEye_Left];
  eyeTextures[ovrEye_Left].OGL.Header.RenderViewport.Pos.x = (width + 1) / 2;

  ovrFovPort eyeFov[2] = { HMD->DefaultEyeFov[0], HMD->DefaultEyeFov[1] };
  union ovrGLConfig config;
  config.OGL.Header.API = ovrRenderAPI_OpenGL;
  config.OGL.Header.RTSize = HMD->Resolution;
  config.OGL.Header.Multisample = false;

  if (!ovrHmd_ConfigureRendering(HMD, &config.Config, ovrDistortionCap_Chromatic | ovrDistortionCap_Vignette | ovrDistortionCap_TimeWarp | ovrDistortionCap_Overdrive, eyeFov, eyeRenderDesc)) {
    if (setupCallback) {
      setupCallback(NULL);
    }
    return;
  }

  ovrHmd_SetEnabledCaps(HMD, ovrHmdCap_LowPersistence | ovrHmdCap_DynamicPrediction | ovrHmdCap_NoMirrorToWindow);
  ovrHmd_ConfigureTracking(HMD, ovrTrackingCap_Orientation | ovrTrackingCap_MagYawCorrection | ovrTrackingCap_Position, 0);

  if (setupCallback) {
    glvr_setup_t info = {
      .width = width,
      .height = height,
      .texture = texture,
    };
    setupCallback(&info);
  }
}

- (void)keyDown:(NSEvent *)event {
  int key = decodeKey(event);
  if (key != -1) {
    keys[key] = true;
    if (keyboardCallback) {
      keyboardCallback(key, true);
    }
  }

  // We don't get menu events since we're doing our own event loop
  if ((key == KEY_W || key == KEY_Q) && ([event modifierFlags] & NSDeviceIndependentModifierFlagsMask) == NSCommandKeyMask) {
    exit(0);
  }
}

- (void)keyUp:(NSEvent *)event {
  int key = decodeKey(event);
  if (key != -1) {
    keys[key] = false;
    if (keyboardCallback) {
      keyboardCallback(key, false);
    }
  }
}

- (void)mouseDown:(NSEvent *)event {
  [self enablePointerLock];
}

- (void)mouseMoved:(NSEvent *)event {
  if (!mouseLock) {
    return;
  }

  mouseInfo.deltaX += [event deltaX];
  mouseInfo.deltaY += [event deltaY];
}

- (void)mouseDragged:(NSEvent *)event {
  [self mouseMoved:event];
}

- (void)windowDidResignKey:(NSNotification *)notification {
  [self disablePointerLock];
}

- (void)enablePointerLock {
  if (mouseLock) {
    return;
  }

  mouseLock = true;
  [NSCursor hide];
  CGDirectDisplayID display = displayFromScreen([NSScreen mainScreen]);
  CGDisplayMoveCursorToPoint(display, CGPointMake(CGDisplayPixelsWide(display) / 2, CGDisplayPixelsHigh(display) / 2));
  CGAssociateMouseAndMouseCursorPosition(false);
}

- (void)disablePointerLock {
  if (!mouseLock) {
    return;
  }
  mouseLock = false;
  [NSCursor unhide];
  CGAssociateMouseAndMouseCursorPosition(true);
}

@end

static void update() {
  uint64_t newTime = mach_absolute_time();
  float seconds = (newTime - oldTime) * timeInfo.numer / timeInfo.denom * 1e-9;
  oldTime = newTime;
  if (updateCallback) {
    updateCallback(seconds);
  }
  mouseInfo.deltaX = mouseInfo.deltaY = 0;
}

static void render() {
  ovrVector3f hmdToEyeViewOffset[2] = { eyeRenderDesc[0].HmdToEyeViewOffset, eyeRenderDesc[1].HmdToEyeViewOffset };
  ovrTrackingState trackingState;
  ovrPosef eyePoses[2];
  ovrHmd_DismissHSWDisplay(HMD);
  ovrHmd_BeginFrame(HMD, 0);
  ovrHmd_GetEyePoses(HMD, 0, hmdToEyeViewOffset, eyePoses, &trackingState);

  if (renderCallback) {
    for (int eye = 0; eye < 2; eye++) {
      const OVR::Posef &pose = eyePoses[eye];
      const auto &fov = eyeRenderDesc[eye].Fov;
      const auto &eyeTexture = eyeTextures[eye];
      const auto &viewport = eyeTexture.OGL.Header.RenderViewport;
      glvr_eye_t info = {
        .index = eye,
        .fov = { fov.LeftTan, fov.RightTan, fov.UpTan, fov.DownTan },
        .translation = { pose.Translation.x, pose.Translation.y, pose.Translation.z },
        .rotation = { pose.Rotation.x, pose.Rotation.y, pose.Rotation.z, pose.Rotation.w },
        .viewport = { viewport.Pos.x, viewport.Pos.y, viewport.Size.w, viewport.Size.h },
      };
      memcpy(info.projection, OVR::Matrix4f(ovrMatrix4f_Projection(eyeRenderDesc[eye].Fov, 0.01f, 10000.0f, true)).Transposed().M[0], sizeof(info.projection));
      memcpy(info.modelview, OVR::Matrix4f(pose).Inverted().Transposed().M[0], sizeof(info.modelview));
      renderCallback(&info);
    }
  }

  ovrHmd_EndFrame(HMD, eyePoses, &eyeTextures[0].Texture);
}

void glvrSetSetupCallback(void (*callback)(glvr_setup_t *setup)) {
  setupCallback = callback;
}

void glvrSetUpdateCallback(void (*callback)(float seconds)) {
  updateCallback = callback;
}

void glvrSetRenderCallback(void (*callback)(glvr_eye_t *eye)) {
  renderCallback = callback;
}

void glvrSetKeyboardCallback(void (*callback)(int key, int down)) {
  keyboardCallback = callback;
}

void glvrRun() {
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

  if (!ovr_Initialize()) {
    if (setupCallback) {
      setupCallback(0);
    }
    return;
  }

  HMD = ovrHmd_Create(0);
  if (!HMD) {
    if (setupCallback) {
      setupCallback(0);
    }
    return;
  }

  NSScreen *target = nil;
  for (NSScreen *screen in [NSScreen screens]) {
    if (HMD->DisplayId == displayFromScreen(screen)) {
      target = screen;
      break;
    }
  }

  if (!target) {
    if (setupCallback) {
      setupCallback(0);
    }
    return;
  }

  NSRect frame = NSMakeRect(0, 0, 320, 240);
  NSRect screen = [[NSScreen mainScreen] frame];
  NSRect bounds = NSOffsetRect(frame,
    screen.origin.x + (screen.size.width - frame.size.width) / 2,
    screen.origin.y + (screen.size.height - frame.size.height) / 2);

  application = [NSApplication sharedApplication];
  view = [[View alloc] initWithFrame:frame];
  window = [[NSWindow alloc] initWithContentRect:bounds styleMask:NSTitledWindowMask | NSClosableWindowMask backing:NSBackingStoreBuffered defer:NO];
  [window setContentView:view];
  [window setInitialFirstResponder:view];
  [window setAcceptsMouseMovedEvents:YES];
  [window setDelegate:view];
  [window setTitle:@"GLVR"];

  // Hiding the main screen may speed stuff up slightly but it makes debugging harder
  #ifdef NDEBUG
    [view enterFullScreenMode:target withOptions:nil];
  #else
    [view enterFullScreenMode:target withOptions:@{ NSFullScreenModeAllScreens: @false }];
  #endif

  [application activateIgnoringOtherApps:YES];
  [window makeKeyAndOrderFront:nil];
  [window makeFirstResponder:view];
  [view enablePointerLock];
  [pool drain];

  #define COMMAND "\xE2\x8C\x98"
  puts("\nUse " COMMAND "W or " COMMAND "Q to exit\n");

  while (true) {
    pool = [[NSAutoreleasePool alloc] init];
    while (NSEvent *event = [application nextEventMatchingMask:NSAnyEventMask untilDate:nil inMode:NSDefaultRunLoopMode dequeue:YES]) {
      [application sendEvent:event];
    }
    update();
    render();
    [pool drain];
  }
}

glvr_mouse_t glvrGetMouseInfo() {
  return mouseInfo;
}

int glvrIsKeyDown(int key) {
  return keys[key];
}
