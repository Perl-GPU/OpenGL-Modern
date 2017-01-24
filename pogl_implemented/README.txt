This directory contains the breakdown of the routines implemented
in the original Perl OpenGL in terms of _c, _s, _p, and non_suffixed.

The contents of the directory are

     README.txt
     
     GL:
     all__.txt  all_c.txt  all_p.txt  all_s.txt
               work_c.tx  work_p.txt work_s.txt
     
     GLP:
     all__.txt
     
     GLU:
     all__.txt  all_c.txt  all_p.txt  all_s.txt
               work_c.txt work_p.txt work_s.txt
     
     GLUT:
     all__.txt
     
     GLX:
     all__.txt

Where README.txt is this file.

The files named all_x.txt list the function names having
suffix _x at the end for x=c,p,s and where x=_ corresponds
to the root OpenGL API function name which is used when
the bindings are unambiguous.

The files named work_x.txt similarly list the functions
with the same naming conventions as the all_x.txt files
but includes the function call signature and argument
types.  The key here is that function arguments of pointer
type in the OpenGL C API are ambiguous and require
special handling.

In the _c files, the pointer types are assumed to be
C pointer values in perl, CPTR.

In the _s files, the pointer types are assumed to be
pointers to packed string objects such as SDL frame
buffersr and PDL data, as PACKED.

In the _p files, pointer arguments indicate perl array
values being input or output.  When the number of
arguments is ambiguous, the implementation uses
references to array objects.  When unambiguous, the
@arrays can be used directly.

NOTE:  The plan for OpenGL::Modern bindings is to have
the _c functions corresponding as closely as possible
in number and type of arguments.  In the more general
case where the pointer arguments correspond to PDL
data, an SDL frame, an OpenGL::Array, or a ref to an
@array, we will use the argument type to implement the
correct interface smoothly as the non_suffixed variant.

