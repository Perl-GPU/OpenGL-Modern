#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <GL/glew.h>
#include <glew-context.c>

#include "gl_counts.h"
#include "gl_errors.h"

static int _done_glewInit = 0;
static int _auto_check_errors = 0;

#define OGLM_CHECK_ERR(name, cleanup) \
  if (_auto_check_errors) { \
    int err = GL_NO_ERROR; \
    int error_count = 0; \
    while ((err = glGetError()) != GL_NO_ERROR) { \
      warn(#name ": OpenGL error: %d %s", err, gl_error_string(err)); \
      error_count++; \
    } \
    if (error_count) { \
      cleanup; \
      croak(#name ": %d OpenGL errors encountered.", error_count); \
    } \
  }
#define OGLM_GLEWINIT \
  if (!_done_glewInit) { \
    GLenum err; \
    glewExperimental = GL_TRUE; \
    err = glewInit(); \
    if (GLEW_OK != err) \
      croak("Error: %s", glewGetErrorString(err)); \
    _done_glewInit++; \
  }
#define OGLM_AVAIL_CHECK(impl, name) \
  if ( !impl ) { \
    croak(#name " not available on this machine"); \
  }
#define OGLM_OUT_SETUP(buffername, n, type) \
  NULL; if (n <= 0) croak("called with invalid n=%d", n); \
  buffername = malloc(sizeof(type) * n); \
  if (!buffername) croak("malloc failed");
#define OGLM_OUT_FINISH(buffername, n, newfunc) \
  EXTEND(sp, n); \
  { int i; for (i=0;i<n;i++) PUSHs(sv_2mortal(newfunc(buffername[i]))); }
#define OGLM_GET_ARGS(varname, startfrom, type, perltype) \
  malloc(sizeof(type) * (items-startfrom)); \
  if (!varname) croak("malloc failed"); \
  { IV i; for(i = 0; i < items-startfrom; i++) { \
    varname[i] = (type)Sv##perltype(ST(i + startfrom)); \
  } }
#define OGLM_GET_SETUP(group, pname, buffertype, buffername) \
  NULL; int pname ## _count = oglm_count_##group(pname); \
  if (pname ## _count < 0) croak("Unknown " #group " %d", pname); \
  buffername = malloc(sizeof(buffertype) * pname ## _count);

/*
  Maybe one day we'll allow Perl callbacks for GLDEBUGPROCARB
*/

MODULE = OpenGL::Modern		PACKAGE = OpenGL::Modern

GLboolean
glewCreateContext(int major=0, int minor=0, int profile_mask=0, int flags=0)
CODE:
  struct createParams params =
  {
#if defined(GLEW_OSMESA)
#elif defined(GLEW_EGL)
#elif defined(_WIN32)
    -1,  /* pixelformat */
#elif !defined(__HAIKU__) && !defined(__APPLE__) || defined(GLEW_APPLE_GLX)
    "",  /* display */
    -1,  /* visual */
#endif
    major,
    minor,
    profile_mask,
    flags
  };
    RETVAL = glewCreateContext(&params);
OUTPUT:
    RETVAL


void
glewDestroyContext()
CODE:
    glewDestroyContext();

UV
glewInit()
CODE:
    glewExperimental = GL_TRUE; /* We want everything that is available on this machine */
    if (_done_glewInit>0) {
        warn("glewInit() called %dX already", _done_glewInit);
    }
    RETVAL = glewInit();
    if ( !RETVAL )
        _done_glewInit++;
OUTPUT:
    RETVAL

char *
glewGetErrorString(err)
    GLenum err
CODE:
    RETVAL = (void *)glewGetErrorString(err);
OUTPUT:
    RETVAL

char *
glewGetString(what)
    GLenum what;
CODE:
    RETVAL = (void *)glewGetString(what);
OUTPUT:
    RETVAL

GLboolean
glewIsSupported(name);
    char* name;
CODE:
    RETVAL = glewIsSupported(name);
OUTPUT:
    RETVAL

#// Test for done with glutInit
int
done_glewInit()
CODE:
    RETVAL = _done_glewInit;
OUTPUT:
    RETVAL

int
glpSetAutoCheckErrors(...)
CODE:
    int state;
    if (items == 1) {
        state = (int)SvIV(ST(0));
        if (state != 0 && state != 1 )
            croak( "Usage: glpSetAutoCheckErrors(1|0)\n" );
        _auto_check_errors = state;
    }
    RETVAL = _auto_check_errors;
OUTPUT:
    RETVAL

void
glpCheckErrors()
CODE:
    int err = GL_NO_ERROR;
    int error_count = 0;
    while ( ( err = glGetError() ) != GL_NO_ERROR ) {
        /* warn( "OpenGL error: %d", err ); */
        warn( "glpCheckErrors: OpenGL error: %d %s", err, gl_error_string(err) );
	error_count++;
    }
    if( error_count )
      croak( "glpCheckErrors: %d OpenGL errors encountered.", error_count );

const char *
glpErrorString(err)
  int err
CODE:
  RETVAL = gl_error_string(err);
OUTPUT:
  RETVAL

# This isn't a bad idea, but I postpone this API and the corresponding
# typemap hackery until later
#GLboolean
#glAreProgramsResidentNV_p(GLuint* ids);
#PPCODE:
#     SV* buf_res = sv_2mortal(newSVpv("",items * sizeof(GLboolean)));
#     GLboolean* residences = (GLboolean*) SvPV_nolen(buf_res);
#     glAreProgramsResidentNV(items, ids, residences);
#     EXTEND(SP, items);
#     int i2;
#     for( i2 = 0; i2 < items; i2++ ) {
#        PUSHs(sv_2mortal(newSViv(residences[i2])));
#	 };

INCLUDE: ../../auto-xs.inc
