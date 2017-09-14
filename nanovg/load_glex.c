#if defined(_WIN32)

#define WIN32_LEAN_AND_MEAN
#define WIN32_EXTRA_LEAN
#include <windows.h>
#include <GL\glu.h>
#include "GL\glext.h"

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

void load_glex() {
  glBlendFuncSeparate = (PFNGLBLENDFUNCSEPARATEPROC) wglGetProcAddress("glBlendFuncSeparate");
  glGetShaderInfoLog = (PFNGLGETSHADERINFOLOGPROC) wglGetProcAddress("glGetShaderInfoLog");
  glGetProgramInfoLog = (PFNGLGETPROGRAMINFOLOGPROC) wglGetProcAddress("glGetProgramInfoLog");
  glCreateProgram = (PFNGLCREATEPROGRAMPROC) wglGetProcAddress("glCreateProgram");
  glCreateShader = (PFNGLCREATESHADERPROC) wglGetProcAddress("glCreateShader");
  glShaderSource = (PFNGLSHADERSOURCEPROC) wglGetProcAddress("glShaderSource");
  glCompileShader = (PFNGLCOMPILESHADERPROC) wglGetProcAddress("glCompileShader");
  glGetShaderiv = (PFNGLGETSHADERIVPROC) wglGetProcAddress("glGetShaderiv");
  glAttachShader = (PFNGLATTACHSHADERPROC) wglGetProcAddress("glAttachShader");
  glBindAttribLocation = (PFNGLBINDATTRIBLOCATIONPROC) wglGetProcAddress("glBindAttribLocation");
  glLinkProgram = (PFNGLLINKPROGRAMPROC) wglGetProcAddress("glLinkProgram");
  glGetProgramiv = (PFNGLGETPROGRAMIVPROC) wglGetProcAddress("glGetProgramiv");
  glDeleteProgram = (PFNGLDELETEPROGRAMPROC) wglGetProcAddress("glDeleteProgram");
  glDeleteShader = (PFNGLDELETESHADERPROC) wglGetProcAddress("glDeleteShader");
  glGetUniformLocation = (PFNGLGETUNIFORMLOCATIONPROC) wglGetProcAddress("glGetUniformLocation");
  glGenBuffers = (PFNGLGENBUFFERSPROC) wglGetProcAddress("glGenBuffers");
  glUniform4fv = (PFNGLUNIFORM4FVPROC) wglGetProcAddress("glUniform4fv");
  glStencilOpSeparate = (PFNGLSTENCILOPSEPARATEPROC) wglGetProcAddress("glStencilOpSeparate");
  glUseProgram = (PFNGLUSEPROGRAMPROC) wglGetProcAddress("glUseProgram");
  glActiveTexture = (PFNGLACTIVETEXTUREPROC) wglGetProcAddress("glActiveTexture");
  glBindBuffer = (PFNGLBINDBUFFERPROC) wglGetProcAddress("glBindBuffer");
  glBufferData = (PFNGLBUFFERDATAPROC) wglGetProcAddress("glBufferData");
  glEnableVertexAttribArray = (PFNGLENABLEVERTEXATTRIBARRAYPROC) wglGetProcAddress("glEnableVertexAttribArray");
  glVertexAttribPointer = (PFNGLVERTEXATTRIBPOINTERPROC) wglGetProcAddress("glVertexAttribPointer");
  glUniform1i = (PFNGLUNIFORM1IPROC) wglGetProcAddress("glUniform1i");
  glUniform2fv = (PFNGLUNIFORM2FVPROC) wglGetProcAddress("glUniform2fv");
  glDisableVertexAttribArray = (PFNGLDISABLEVERTEXATTRIBARRAYPROC) wglGetProcAddress("glDisableVertexAttribArray");
  glDeleteBuffers = (PFNGLDELETEBUFFERSPROC) wglGetProcAddress("glDeleteBuffers");

  glGetUniformBlockIndex = (PFNGLGETUNIFORMBLOCKINDEXPROC) wglGetProcAddress("glGetUniformBlockIndex");
  glGenVertexArrays = (PFNGLGENVERTEXARRAYSPROC) wglGetProcAddress("glGenVertexArrays");
  glUniformBlockBinding = (PFNGLUNIFORMBLOCKBINDINGPROC) wglGetProcAddress("glUniformBlockBinding");
  glGenerateMipmap = (PFNGLGENERATEMIPMAPPROC) wglGetProcAddress("glGenerateMipmap");
  glBindBufferRange = (PFNGLBINDBUFFERRANGEPROC) wglGetProcAddress("glBindBufferRange");
  glBindVertexArray = (PFNGLBINDVERTEXARRAYPROC) wglGetProcAddress("glBindVertexArray");
  glDeleteVertexArrays = (PFNGLDELETEVERTEXARRAYSPROC) wglGetProcAddress("glDeleteVertexArrays");
}

#endif
