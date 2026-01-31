extern int _done_glewInit;
extern int _auto_check_errors;

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
#define OGLM_OUT_FINISH(buffername, n, newfunc) \
  EXTEND(sp, n); \
  { int i; for (i=0;i<n;i++) mPUSHs(newfunc(buffername[i])); }
#define OGLM_GET_VARARGS(varname, startfrom, type, perltype, howmany) \
  NULL; if (items-(startfrom) != (howmany)) \
    croak("error: expected %d args but given %d", howmany, items-(startfrom)); \
  varname = OGLM_ALLOC(howmany, type, varname); \
  { IV i; for(i = 0; i < (howmany); i++) { \
    varname[i] = (type)Sv##perltype(ST(i + (startfrom))); \
  } }
#define OGLM_SIZE_ENUM(group, pname, mult) \
  int pname ## _count = oglm_count_##group(pname) * (mult); \
  if (pname ## _count < 0) croak("Unknown " #group " %d", pname);
#define OGLM_ALLOC(size, buffertype, buffername) \
  NULL; if (size <= 0) croak("called with invalid n=%d", size); \
  buffername = malloc(sizeof(buffertype) * size); \
  if (!buffername) croak("malloc failed");
