#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <GL/glew.h>

extern int _done_glewInit;
extern int _auto_check_errors;
#include "gl_errors.h"
#include "oglm.h"

#define OGL_CONST_i(test) newCONSTSUB(stash, #test, newSViv((IV)test));

MODULE = OpenGL::Modern::Const		PACKAGE = OpenGL::Modern

BOOT:
  HV *stash = gv_stashpvn("OpenGL::Modern", strlen("OpenGL::Modern"), TRUE);
#include "const.h"

INCLUDE: ../../../auto-xs-var.inc
