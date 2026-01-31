#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <GL/glew.h>

#include "gl_errors.h"
#include "oglm.h"

#define OGL_CONST_i(test) newCONSTSUB(stash, #test, newSViv((IV)test));

MODULE = OpenGL::Modern::Const		PACKAGE = OpenGL::Modern

INCLUDE: ../../../auto-xs-var.inc

BOOT:
  HV *stash = gv_stashpvn("OpenGL::Modern", strlen("OpenGL::Modern"), TRUE);
#include "const.h"
