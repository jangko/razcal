#if defined(_WIN32)

#define WIN32_LEAN_AND_MEAN
#define WIN32_EXTRA_LEAN
#include <windows.h>
#include <GL\glu.h>
#include "GL\glext.h"
#include <stdio.h>

PFNGLBLENDFUNCSEPARATEPROC glBlendFuncSeparate;
PFNGLGETSHADERINFOLOGPROC glGetShaderInfoLog;
PFNGLGETPROGRAMINFOLOGPROC glGetProgramInfoLog;
PFNGLCREATEPROGRAMPROC glCreateProgram;
PFNGLCREATESHADERPROC glCreateShader;
PFNGLSHADERSOURCEPROC glShaderSource;
PFNGLCOMPILESHADERPROC glCompileShader;
PFNGLGETSHADERIVPROC glGetShaderiv;
PFNGLATTACHSHADERPROC glAttachShader;
PFNGLBINDATTRIBLOCATIONPROC glBindAttribLocation;
PFNGLLINKPROGRAMPROC glLinkProgram;
PFNGLGETPROGRAMIVPROC glGetProgramiv;
PFNGLDELETEPROGRAMPROC glDeleteProgram;
PFNGLDELETESHADERPROC glDeleteShader;
PFNGLGETUNIFORMLOCATIONPROC glGetUniformLocation;
PFNGLGENBUFFERSPROC glGenBuffers;
PFNGLUNIFORM4FVPROC glUniform4fv;
PFNGLSTENCILOPSEPARATEPROC glStencilOpSeparate;
PFNGLUSEPROGRAMPROC glUseProgram;
PFNGLACTIVETEXTUREPROC glActiveTexture;
PFNGLBINDBUFFERPROC glBindBuffer;
PFNGLBUFFERDATAPROC glBufferData;
PFNGLENABLEVERTEXATTRIBARRAYPROC glEnableVertexAttribArray;
PFNGLVERTEXATTRIBPOINTERPROC glVertexAttribPointer;
PFNGLUNIFORM1IPROC glUniform1i;
PFNGLUNIFORM2FVPROC glUniform2fv;
PFNGLDISABLEVERTEXATTRIBARRAYPROC glDisableVertexAttribArray;
PFNGLDELETEBUFFERSPROC glDeleteBuffers;

PFNGLGETUNIFORMBLOCKINDEXPROC glGetUniformBlockIndex;
PFNGLGENVERTEXARRAYSPROC glGenVertexArrays;
PFNGLUNIFORMBLOCKBINDINGPROC glUniformBlockBinding;
PFNGLGENERATEMIPMAPPROC glGenerateMipmap;
PFNGLBINDBUFFERRANGEPROC glBindBufferRange;
PFNGLBINDVERTEXARRAYPROC glBindVertexArray;
PFNGLDELETEVERTEXARRAYSPROC glDeleteVertexArrays;

#define LOADPFNGL(GLVAR, PFNGL, FNNAME) \
  GLVAR = (PFNGL) wglGetProcAddress(FNNAME); \
  if(GLVAR == NULL) { \
    printf(stderr, "`%s` cannot be loaded\n", FNNAME); \
    numErr++; \
  }

#endif

void load_glex() {
  int numErr = 0;

#if defined(_WIN32)
  LOADPFNGL(glBlendFuncSeparate, PFNGLBLENDFUNCSEPARATEPROC, "glBlendFuncSeparate");
  LOADPFNGL(glGetShaderInfoLog, PFNGLGETSHADERINFOLOGPROC, "glGetShaderInfoLog");
  LOADPFNGL(glGetProgramInfoLog, PFNGLGETPROGRAMINFOLOGPROC, "glGetProgramInfoLog");
  LOADPFNGL(glCreateProgram, PFNGLCREATEPROGRAMPROC, "glCreateProgram");
  LOADPFNGL(glCreateShader, PFNGLCREATESHADERPROC, "glCreateShader");
  LOADPFNGL(glShaderSource, PFNGLSHADERSOURCEPROC, "glShaderSource");
  LOADPFNGL(glCompileShader, PFNGLCOMPILESHADERPROC, "glCompileShader");
  LOADPFNGL(glGetShaderiv, PFNGLGETSHADERIVPROC, "glGetShaderiv");
  LOADPFNGL(glAttachShader, PFNGLATTACHSHADERPROC, "glAttachShader");
  LOADPFNGL(glBindAttribLocation, PFNGLBINDATTRIBLOCATIONPROC, "glBindAttribLocation");
  LOADPFNGL(glLinkProgram, PFNGLLINKPROGRAMPROC, "glLinkProgram");
  LOADPFNGL(glGetProgramiv, PFNGLGETPROGRAMIVPROC, "glGetProgramiv");
  LOADPFNGL(glDeleteProgram, PFNGLDELETEPROGRAMPROC, "glDeleteProgram");
  LOADPFNGL(glDeleteShader, PFNGLDELETESHADERPROC, "glDeleteShader");
  LOADPFNGL(glGetUniformLocation, PFNGLGETUNIFORMLOCATIONPROC, "glGetUniformLocation");
  LOADPFNGL(glGenBuffers, PFNGLGENBUFFERSPROC, "glGenBuffers");
  LOADPFNGL(glUniform4fv, PFNGLUNIFORM4FVPROC, "glUniform4fv");
  LOADPFNGL(glStencilOpSeparate, PFNGLSTENCILOPSEPARATEPROC, "glStencilOpSeparate");
  LOADPFNGL(glUseProgram, PFNGLUSEPROGRAMPROC, "glUseProgram");
  LOADPFNGL(glActiveTexture, PFNGLACTIVETEXTUREPROC, "glActiveTexture");
  LOADPFNGL(glBindBuffer, PFNGLBINDBUFFERPROC, "glBindBuffer");
  LOADPFNGL(glBufferData, PFNGLBUFFERDATAPROC, "glBufferData");
  LOADPFNGL(glEnableVertexAttribArray, PFNGLENABLEVERTEXATTRIBARRAYPROC, "glEnableVertexAttribArray");
  LOADPFNGL(glVertexAttribPointer, PFNGLVERTEXATTRIBPOINTERPROC, "glVertexAttribPointer");
  LOADPFNGL(glUniform1i, PFNGLUNIFORM1IPROC, "glUniform1i");
  LOADPFNGL(glUniform2fv, PFNGLUNIFORM2FVPROC, "glUniform2fv");
  LOADPFNGL(glDisableVertexAttribArray, PFNGLDISABLEVERTEXATTRIBARRAYPROC, "glDisableVertexAttribArray");
  LOADPFNGL(glDeleteBuffers, PFNGLDELETEBUFFERSPROC, "glDeleteBuffers");

  LOADPFNGL(glGetUniformBlockIndex, PFNGLGETUNIFORMBLOCKINDEXPROC, "glGetUniformBlockIndex");
  LOADPFNGL(glGenVertexArrays, PFNGLGENVERTEXARRAYSPROC, "glGenVertexArrays");
  LOADPFNGL(glUniformBlockBinding, PFNGLUNIFORMBLOCKBINDINGPROC, "glUniformBlockBinding");
  LOADPFNGL(glGenerateMipmap, PFNGLGENERATEMIPMAPPROC, "glGenerateMipmap");
  LOADPFNGL(glBindBufferRange, PFNGLBINDBUFFERRANGEPROC, "glBindBufferRange");
  LOADPFNGL(glBindVertexArray, PFNGLBINDVERTEXARRAYPROC, "glBindVertexArray");
  LOADPFNGL(glDeleteVertexArrays, PFNGLDELETEVERTEXARRAYSPROC, "glDeleteVertexArrays");
#endif

  if(numErr > 0) exit(1);
}