#include <stdlib.h>
#include <stdio.h>
#include "glvr.h"

static GLuint framebuffer;
static GLuint program;
static GLuint buffer;
static int projection;
static int modelview;

static float x = 0.5;
static float y = 0.5;

static void setup(glvr_setup_t *setup) {
  if (!setup) {
    puts("Could not initialize GLVR");
    exit(1);
  }

  glGenFramebuffers(1, &framebuffer);
  glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
  glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, setup->texture, 0);
  glBindFramebuffer(GL_FRAMEBUFFER, 0);

  const char *vertexSource =
    "uniform mat4 projection;"
    "uniform mat4 modelview;"
    "attribute vec3 aVertex;"
    "attribute vec4 aColor;"
    "varying vec4 vColor;"
    "void main() {"
    "  vColor = aColor;"
    "  gl_Position = projection * modelview * vec4(aVertex, 1.0);"
    "}";
  const char *fragmentSource =
    "varying vec4 vColor;"
    "void main() {"
    "  gl_FragColor = vColor;"
    "}";

  int vertex = glCreateShader(GL_VERTEX_SHADER);
  int fragment = glCreateShader(GL_FRAGMENT_SHADER);
  program = glCreateProgram();
  glShaderSource(vertex, 1, &vertexSource, NULL);
  glShaderSource(fragment, 1, &fragmentSource, NULL);
  glCompileShader(vertex);
  glCompileShader(fragment);
  glAttachShader(program, vertex);
  glAttachShader(program, fragment);
  glLinkProgram(program);
  glGenBuffers(1, &buffer);
  projection = glGetUniformLocation(program, "projection");
  modelview = glGetUniformLocation(program, "modelview");
}

static void update(float seconds) {
  const auto &mouse = glvrGetMouseInfo();
  x += mouse.deltaX / 1000;
  y += mouse.deltaY / 1000;
}

static void render(glvr_eye_t *eye) {
  const auto &viewport = eye->viewport;
  glBindFramebuffer(GL_FRAMEBUFFER, framebuffer);
  glViewport(viewport[0], viewport[1], viewport[2], viewport[3]);
  glScissor(viewport[0], viewport[1], viewport[2], viewport[3]);
  glEnable(GL_SCISSOR_TEST);

  glClearColor(x, y, 0, 1);
  glClear(GL_COLOR_BUFFER_BIT);

  struct Vertex {
    float x, y, z;
    unsigned char r, g, b, a;
  };

  static_assert(sizeof(Vertex) == 16, "");

  Vertex data[] = {
    { -0.25, -0.25, -1,   0xFF, 0, 0, 0xFF },
    { +0.25, -0.25, -1,   0xFF, 0, 0, 0xFF },
    { -0.25, +0.25, -1,   0xFF, 0, 0, 0xFF },
    { +0.25, +0.25, -1,   0xFF, 0, 0, 0xFF },

    { -0.25, -0.25, -0.5, 0xFF, 0xFF, 0, 0xFF },
    {  0,    -0.25, -0.5, 0xFF, 0xFF, 0, 0xFF },
    { -0.25,  0,    -0.5, 0xFF, 0xFF, 0, 0xFF },
    {  0,     0,    -0.5, 0xFF, 0xFF, 0, 0xFF },
  };

  glBindBuffer(GL_ARRAY_BUFFER, buffer);
  glBufferData(GL_ARRAY_BUFFER, sizeof(data), data, GL_DYNAMIC_DRAW);
  glEnableVertexAttribArray(0);
  glEnableVertexAttribArray(1);
  glVertexAttribPointer(0, 3, GL_FLOAT, false, sizeof(Vertex), (void *)0);
  glVertexAttribPointer(1, 4, GL_UNSIGNED_BYTE, true, sizeof(Vertex), (void *)12);
  glUseProgram(program);
  glUniformMatrix4fv(projection, 1, false, eye->projection);
  glUniformMatrix4fv(modelview, 1, false, eye->modelview);
  glDrawArrays(GL_TRIANGLE_STRIP, 0, sizeof(data) / sizeof(*data));
  glUseProgram(0);
  glBindBuffer(GL_ARRAY_BUFFER, 0);

  glDisable(GL_SCISSOR_TEST);
  glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

int main() {
  glvrSetSetupCallback(setup);
  glvrSetUpdateCallback(update);
  glvrSetRenderCallback(render);
  glvrRun();
  return 0;
}
