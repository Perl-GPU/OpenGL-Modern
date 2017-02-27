#!/usr/bin/perl
use strict;
use warnings;
use Test::More;

BEGIN {
    plan skip_all => "test requires old OpenGL.pm for now" if !eval { require OpenGL;       1 };
    plan skip_all => "test requires OpenGL::GLUT"          if !eval { require OpenGL::GLUT; 1 };
}

use OpenGL::GLUT
  map( "glut$_", qw' Init InitDisplayMode InitWindowSize CreateWindow IdleFunc
      DisplayFunc ReshapeFunc KeyboardFunc SpecialFunc KeyboardUpFunc MouseFunc
      SpecialUpFunc CloseFunc SetOption MainLoop WireTeapot BitmapCharacter Get
      SwapBuffers HideWindow DestroyWindow LeaveMainLoop GetModifiers
      GameModeGet EnterGameMode LeaveGameMode GameModeString ' ),
  map( "GLUT_$_", qw' ACTIVE_SHIFT ACTIVE_CTRL ACTIVE_ALT BITMAP_HELVETICA_12 UP
      WINDOW_WIDTH WINDOW_HEIGHT KEY_PAGE_UP KEY_PAGE_DOWN KEY_UP KEY_DOWN ALPHA
      KEY_LEFT KEY_RIGHT LEFT_BUTTON MIDDLE_BUTTON RIGHT_BUTTON DOWN DOUBLE RGBA
      ACTION_ON_WINDOW_CLOSE ACTION_GLUTMAINLOOP_RETURNS GAME_MODE_WIDTH DEPTH
      DISPLAY_MODE_POSSIBLE GAME_MODE_HEIGHT' );

use OpenGL::Modern qw':all';

use OpenGL::Modern::Helpers qw' glGenTextures_p glGenBuffers_p
  glGenFramebuffers_p glBufferData_p glGenProgramsARB_p glGenRenderbuffers_p
  glBufferSubData_p ';

use OpenGL qw' glpCheckExtension glpFullScreen glpRestoreScreen ',    # glp

  qw' gluBuild2DMipmaps_c gluPerspective gluOrtho2D gluUnProject_p gluErrorString ',    # glu

  qw' glProgramStringARB_p
  glMapBufferARB_p glGetBufferSubDataARB_p
  glLightfv_p
  glDeleteProgramsARB_p glDeleteFramebuffersEXT_p glDeleteRenderbuffersEXT_p glDeleteBuffersARB_p glDeleteTextures_p
  glGetBufferParameterivARB_p glGetProgramStringARB_p glGetProgramivARB_p glGetProgramEnvParameterdvARB_p glGetProgramEnvParameterfvARB_p
  glVertexPointer_p glColorPointer_p glTexCoordPointer_p glNormalPointer_p

  glTexImage2D_s glTexImage2D_p
  ';                                                                                    # _p

BEGIN { eval 'use Time::HiRes "time"' }    # necessary to do at BEGIN so time() will be imported

use constant PROGRAM_TITLE      => "OpenGL Test App";
use constant DO_TESTS           => 1;
use constant FRAME_RATE_SAMPLES => 50;

my $hasHires  = eval 'use Time::HiRes; 1';
my $hasImage  = eval 'use OpenGL::Image 1.03; 1';
my $hasIM     = eval 'use Image::Magick; 1';
my $hasShader = eval 'use OpenGL::Shader; 1';
my $hasIM_635 = $hasImage && OpenGL::Image::HasEngine( 'Magick', '6.3.5' );

my $FrameCount = 0;
my $last       = 0;
my $FrameRate  = 0;
my @rainbow_inc;
my $hasVBO = 0;
my ( $VertexObjID, $NormalObjID, $ColorObjID, $TexCoordObjID, $IndexObjID );

my $verts_oga = OpenGL::Array->new_list( GL_FLOAT,
    -1.0, -1.3, -1.0,
    1.0,  -1.3, -1.0,
    1.0,  -1.3, 1.0,
    -1.0, -1.3, 1.0,

    -1.0, 1.3, -1.0,
    -1.0, 1.3, 1.0,
    1.0,  1.3, 1.0,
    1.0,  1.3, -1.0,

    -1.0, -1.0, -1.3,
    -1.0, 1.0,  -1.3,
    1.0,  1.0,  -1.3,
    1.0,  -1.0, -1.3,

    1.3, -1.0, -1.0,
    1.3, 1.0,  -1.0,
    1.3, 1.0,  1.0,
    1.3, -1.0, 1.0,

    -1.0, -1.0, 1.3,
    1.0,  -1.0, 1.3,
    1.0,  1.0,  1.3,
    -1.0, 1.0,  1.3,

    -1.3, -1.0, -1.0,
    -1.3, -1.0, 1.0,
    -1.3, 1.0,  1.0,
    -1.3, 1.0,  -1.0
);

my $norms_oga =
  OpenGL::Array->new_list( GL_FLOAT, 0.0, -1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, -1.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, -1.0,
    0.0, 0.0 );

my $colors_oga = OpenGL::Array->new_list( GL_FLOAT,
    0.9, 0.2, 0.2, .75,
    0.9, 0.2, 0.2, .75,
    0.9, 0.2, 0.2, .75,
    0.9, 0.2, 0.2, .75,

    0.5, 0.5, 0.5, .5,
    0.5, 0.5, 0.5, .5,
    0.5, 0.5, 0.5, .5,
    0.5, 0.5, 0.5, .5,

    0.2, 0.9, 0.2, .5,
    0.2, 0.9, 0.2, .5,
    0.2, 0.9, 0.2, .5,
    0.2, 0.9, 0.2, .5,

    0.2, 0.2, 0.9, .25,
    0.2, 0.2, 0.9, .25,
    0.2, 0.2, 0.9, .25,
    0.2, 0.2, 0.9, .25,

    0.9, 0.2, 0.2, 0.5,
    0.2, 0.9, 0.2, 0.5,
    0.2, 0.2, 0.9, 0.5,
    0.1, 0.1, 0.1, 0.5,

    0.9, 0.9, 0.2, 0.0,
    0.9, 0.9, 0.2, 0.66,
    0.9, 0.9, 0.2, 1.0,
    0.9, 0.9, 0.2, 0.33
);

my @rainbow = ( 0.9, 0.2, 0.2, 0.5, 0.2, 0.9, 0.2, 0.5, 0.2, 0.2, 0.9, 0.5, 0.1, 0.1, 0.1, 0.5 );
my $rainbow_oga = OpenGL::Array->new_list( GL_FLOAT, @rainbow );
my $rainbow_offset = 64;

my $texcoords_oga = OpenGL::Array->new_list( GL_FLOAT,
    0.800, 0.800,
    0.200, 0.800,
    0.200, 0.200,
    0.800, 0.200,

    0.005, 1.995,
    0.005, 0.005,
    1.995, 0.005,
    1.995, 1.995,

    0.995,  0.005,
    2.995,  2.995,
    0.005,  0.995,
    -1.995, -1.995,

    0.995, 0.005,
    0.995, 0.995,
    0.005, 0.995,
    0.005, 0.005,

    -0.5, -0.5,
    1.5,  -0.5,
    1.5,  1.5,
    -0.5, 1.5,

    0.005, 0.005,
    0.995, 0.005,
    0.995, 0.995,
    0.005, 0.995
);

my @indices = 0 .. 23;
my $indices_oga = OpenGL::Array->new_list( GL_UNSIGNED_INT, @indices );

my ( $TextureID_image, $TextureID_FBO );

# Settings for our light.  Try playing with these (or add more lights).
my @Light_Position = ( 2.0, 2.0, 0.0, 1.0 );
my @Light_Ambient  = ( 0.1, 0.1, 0.1, 1.0 );
my @Light_Diffuse  = ( 1.2, 1.2, 1.2, 1.0 );

my $Tex_File   = 't/data/test.tga';
my $Tex_Width  = 128;
my $Tex_Height = 128;
my $Tex_Type;
my $Tex_Format;
my $Tex_Size;
my $Tex_Image;
my $Tex_Pixels_oga;

my $useMipMap = 1;
my $hasFBO    = 0;

my $FrameBufferID;
my $RenderBufferID;
my $FBO_On = 0;
my $Shader;

my $hasFragProg = 0;
my $VertexProgID;
my $FragProgID;

my $idleSecsMax  = 5;
my $idleTime     = time;
my $FBO_rendered = 0;
my $Teapot_Rot   = 0.0;

my $xform_oga =
  OpenGL::Array->new_list( GL_FLOAT, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0 );

my $Texture_On    = 1;
my $Light_On      = 0;
my $Alpha_Add     = 1;
my $Blend_On      = 0;
my $Z_Off         = -5.0;
my $X_Rot         = 0.9;
my $Y_Rot         = 0.0;
my $Window_Width  = 300;
my $Window_Height = 300;
my @TexModesStr   = qw/ GL_DECAL GL_MODULATE GL_BLEND GL_REPLACE /;
my $Curr_TexMode  = 0;
my $Inset_On      = 1;
my $X_Speed       = 0.0;
my $Y_Speed       = 0.5;
my $er;
my $Inset_Width  = 90;
my $Inset_Height = 90;

my $gameMode;
if ( scalar( @ARGV ) and lc( $ARGV[0] ) eq 'gamemode' ) {
    $gameMode = $ARGV[1] || '';
}

my $Window_ID;
my @TexModes = ( GL_DECAL, GL_MODULATE, GL_BLEND, GL_REPLACE );
my $Fullscreen_On = 0;
my $Window_State;

my $mm_oga = OpenGL::Array->new( 16, GL_DOUBLE );
my $pm_oga = OpenGL::Array->new( 16, GL_DOUBLE );
my $vp_oga = OpenGL::Array->new( 4,  GL_INT );

run();
done_testing;

sub run {
    my $stat = `perl -v`;
    our $PERL_VERSION = $^V;
    $PERL_VERSION =~ s|^v||;

    glutInit;

    # To see OpenGL drawing, take out the GLUT_DOUBLE request.
    glutInitDisplayMode GLUT_RGBA | GLUT_DOUBLE | GLUT_DEPTH | GLUT_ALPHA;

    if ( $^O ne 'MSWin32' ) {    # skip these MODE checks on win32, they don't work
        if ( not glutGet GLUT_DISPLAY_MODE_POSSIBLE ) {
            warn "glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE | GLUT_DEPTH | GLUT_ALPHA) not possible";
            warn "...trying without GLUT_ALPHA";

            # try without GLUT_ALPHA
            glutInitDisplayMode GLUT_RGBA | GLUT_DOUBLE | GLUT_DEPTH;
            if ( not glutGet GLUT_DISPLAY_MODE_POSSIBLE ) {
                warn "glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE | GLUT_DEPTH) not possible, exiting quietly";
                exit 0;
            }
        }
    }

    if ( defined $gameMode and glutGameModeString $gameMode ) {
        note "Running in Game Mode $gameMode\n";
        glutGameModeString $gameMode ;
        $Window_ID     = glutEnterGameMode;
        $Window_Width  = glutGameModeGet GLUT_GAME_MODE_WIDTH;
        $Window_Height = glutGameModeGet GLUT_GAME_MODE_HEIGHT;
    }
    else {
        glutInitWindowSize $Window_Width, $Window_Height;
        $Window_ID = glutCreateWindow PROGRAM_TITLE;
    }

    # Get OpenGL Info
    note "\n" . PROGRAM_TITLE;
    note ' (using hires timer)' if $hasHires;
    note "\n\n";
    my $version  = glGetString GL_VERSION;
    my $vendor   = glGetString GL_VENDOR;
    my $renderer = glGetString GL_RENDERER;
    note "Using POGL v$OpenGL::BUILD_VERSION\n"
      . "OpenGL installation: $version\n$vendor\n$renderer\n\n"
      . "Installed extensions (* implemented in the module):\n";
    my $extensions = glGetString GL_EXTENSIONS;
    my @extensions = split ' ', $extensions;

    for my $ext ( sort @extensions ) {
        my $stat = glpCheckExtension $ext ;
        note sprintf "%s $ext\n", $stat ? ' ' : '*';
        note "    $stat\n" if $stat and $stat !~ m|^$ext |;
    }

    $hasVBO = ( $PERL_VERSION !~ m|^5\.10\.| )    # Perl 5.10 crashes on VBOs!
      if not glpCheckExtension 'GL_ARB_vertex_buffer_object';

    if ( not glpCheckExtension 'GL_EXT_framebuffer_object' ) {
        $hasFBO = 1;
        $FBO_On = 1;
        if ( not glpCheckExtension 'GL_ARB_fragment_program' ) {
            $hasFragProg = 1;
            $FBO_On++;
        }
    }

    glutDisplayFunc \&cbRenderScene;              # Register the callback function to do the drawing.
    glutIdleFunc \&cbRenderScene;                 # If there's nothing to do, draw.
    glutReshapeFunc \&cbResizeScene;              # It's a good idea to know when our window's resized.
    glutKeyboardFunc \&cbKeyPressed;              # And let's get some keyboard input.
    glutSpecialFunc \&cbSpecialKeyPressed;
    glutKeyboardUpFunc \&cbKeyUp;
    glutSpecialUpFunc \&cbSpecialKeyUp;
    glutMouseFunc \&cbMouseClick;                 # Mouse handlers.
    glutCloseFunc \&cbClose if OpenGL::_have_freeglut();    # Handle window close events.

    ourInit( $Window_Width, $Window_Height );    # OK, OpenGL's ready to go.  Let's call our own init function.

    note qq{
Hold down arrow keys to rotate, 'r' to reverse, 's' to stop.
Page up/down will move cube away from/towards camera.
Use first letter of shown display mode settings to alter.
Press 'g' to toggle fullscreen mode (not supported on all platforms).
Press 'c' to capture/save a RGBA targa file.
'q' or [Esc] to quit; OpenGL window must have focus for input.

};

    if ( OpenGL::_have_freeglut() ) {
        note "Setting window close to trigger return from mainloop (freeglut).\n";
        glutSetOption GLUT_ACTION_ON_WINDOW_CLOSE, GLUT_ACTION_GLUTMAINLOOP_RETURNS;
    }

    note "Entering glutMainLoop\n";
    glutMainLoop;
    note "Returned from glutMainLoop\n";

    note "Exiting in main thread\n";

    pass "looks like nothing too bad happened";
}

# ------
# Frames per second (FPS) statistic variables and routine.

sub ourDoFPS {
    return if ++$FrameCount < FRAME_RATE_SAMPLES;

    my $now   = time;
    my $delta = $now - $last;
    $last = $now;

    $FrameRate = FRAME_RATE_SAMPLES / ( $delta || 1 );
    $FrameCount = 0;
}

# ------
# String rendering routine; leverages on GLUT routine.

sub ourPrintString {
    my ( $font, $str ) = @_;
    my @c = split '', $str;
    glutBitmapCharacter $font, ord $_ for @c;
}

# ------
# Does everything needed before losing control to the main
# OpenGL event loop.

sub ourInitVertexBuffers {

    # Set initial colors for rainbow face
    for ( my $i = 0 ; $i < 16 ; $i++ ) {
        $rainbow[$i]     = rand 1.0;
        $rainbow_inc[$i] = 0.01 - rand 0.02;
    }

    # Initialize VBOs if supported
    if ( $hasVBO ) {
        note "Using VBOs\n";

        ( $VertexObjID, $NormalObjID, $ColorObjID, $TexCoordObjID, $IndexObjID ) = glGenBuffers_p 5;

        #glBindBufferARB(GL_ARRAY_BUFFER_ARB, $VertexObjID);
        $verts_oga->bind( $VertexObjID );
        glBufferData_p GL_ARRAY_BUFFER_ARB, $verts_oga, GL_STATIC_DRAW_ARB;
        glVertexPointer_c 3, GL_FLOAT, 0, 0;

        if ( DO_TESTS ) {
            note "\nTests:\n";

            my $size = glGetBufferParameterivARB_p GL_ARRAY_BUFFER_ARB, GL_BUFFER_SIZE_ARB;
            note "  Vertex Buffer Size (bytes): $size\n";
            my $count = $verts_oga->elements;
            note "  Vertex Buffer Size (elements): $count\n";

            my $test = glGetBufferSubDataARB_p GL_ARRAY_BUFFER_ARB, 12, 3, GL_FLOAT;
            my @test = $test->retrieve( 0, 3 );
            my $ords = join '/', @test;
            note "  glGetBufferSubDataARB_p: $ords\n";
        }

        #glBindBufferARB(GL_ARRAY_BUFFER_ARB, $NormalObjID);
        $norms_oga->bind( $NormalObjID );
        glBufferData_p GL_ARRAY_BUFFER_ARB, $norms_oga, GL_STATIC_DRAW_ARB;
        glNormalPointer_c GL_FLOAT, 0, 0;

        #glBindBufferARB(GL_ARRAY_BUFFER_ARB, $ColorObjID);
        $colors_oga->bind( $ColorObjID );
        glBufferData_p GL_ARRAY_BUFFER_ARB, $colors_oga, GL_DYNAMIC_DRAW_ARB;
        $rainbow_oga->assign( 0, @rainbow );
        glBufferSubData_p GL_ARRAY_BUFFER_ARB, $rainbow_offset, $rainbow_oga;
        glColorPointer_c 4, GL_FLOAT, 0, 0;

        #glBindBufferARB(GL_ARRAY_BUFFER_ARB, $TexCoordObjID);
        $texcoords_oga->bind( $TexCoordObjID );
        glBufferData_p GL_ARRAY_BUFFER_ARB, $texcoords_oga, GL_STATIC_DRAW_ARB;
        glTexCoordPointer_c 2, GL_FLOAT, 0, 0;

        #glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER_ARB, $IndexObjID);
        $indices_oga->bind( $IndexObjID );
        glBufferData_p GL_ELEMENT_ARRAY_BUFFER_ARB, $indices_oga, GL_STATIC_DRAW_ARB;
    }
    else {
        note "Using classic Vertex Buffers\n";
        glVertexPointer_p 3, $verts_oga;
        glNormalPointer_p $norms_oga ;
        $colors_oga->assign( $rainbow_offset, @rainbow );
        glColorPointer_p 4,    $colors_oga;
        glTexCoordPointer_p 2, $texcoords_oga;
    }
    note "-- done\n";
}

sub ourInit {
    my ( $Width, $Height ) = @_;

    note "\nUsing POGL v$OpenGL::VERSION\n";

    # Build texture.
    ( $TextureID_image, $TextureID_FBO ) = glGenTextures_p 2;
    ourBuildTextures();
    glTexEnvf GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_DECAL;

    # Initialize shaders.
    ourInitShaders();

    # Initialize vertex buffers
    ourInitVertexBuffers();

    # Initialize rendering parameters
    glEnable GL_TEXTURE_2D;
    glDisable GL_LIGHTING;
    glBlendFunc GL_SRC_ALPHA, GL_ONE;

    # Color to clear color buffer to.
    glClearColor 0.1, 0.1, 0.1, 0.0;

    # Depth to clear depth buffer to; type of test.
    glClearDepth 1.0;
    glDepthFunc GL_LESS;

    # Enables Smooth Color Shading; try GL_FLAT for (lack of) fun.
    glShadeModel GL_SMOOTH;

    # Load up the correct perspective matrix; using a callback directly.
    cbResizeScene( $Width, $Height );

    # Set up a light, turn it on.
    glLightfv_p GL_LIGHT1, GL_POSITION, @Light_Position;
    glLightfv_p GL_LIGHT1, GL_AMBIENT,  @Light_Ambient;
    glLightfv_p GL_LIGHT1, GL_DIFFUSE,  @Light_Diffuse;
    glEnable GL_LIGHT1;

    # A handy trick -- have surface material mirror the color.
    glColorMaterial GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE;
    glEnable GL_COLOR_MATERIAL;
}

# ------
# Function to build a simple full-color texture with alpha channel,
# and then create mipmaps.
# Also sets up FBO texture and Vertex/Fragment programs.

sub ourBuildTextures {
    my $tex;

    ( $TextureID_image, $TextureID_FBO ) = glGenTextures_p 2;    # Build Image Texture

    if ( $hasImage && -e $Tex_File ) {                           # Use OpenGL::Image to load texture
        my $img = OpenGL::Image->new( source => $Tex_File );
        die $@ if $@;
        my ( $eng, $ver ) = $img->Get( 'engine', 'version' );
        note "Using OpenGL::Image - $eng v$ver\n";

        ( $Tex_Width, $Tex_Height ) = $img->Get( 'width', 'height' );
        my $alpha = $img->Get( 'alpha' ) ? 'has' : 'no';
        note "Loading texture: $Tex_File, $Tex_Width x $Tex_Height, $alpha alpha\n";

        ( $Tex_Type, $Tex_Format, $Tex_Size ) = $img->Get( 'gl_internalformat', 'gl_format', 'gl_type' );

        # Use OGA for testing
        $Tex_Image      = $img;
        $Tex_Pixels_oga = $img->GetArray;
        note "Using ImageMagick's gaussian blur on inset\n" if ( $hasIM_635 );
    }
    else {    # Build texture from scratch if OpenGL::Image not available
        my $hole_size = 3300;    # ~ == 57.45 ^ 2.
                                 # Iterate across the texture array.
        for ( my $y = 0 ; $y < $Tex_Height ; $y++ ) {
            for ( my $x = 0 ; $x < $Tex_Width ; $x++ ) {

                # A simple repeating squares pattern.
                # Dark blue on white.
                if ( ( ( $x + 4 ) % 32 < 8 ) && ( ( $y + 4 ) % 32 < 8 ) ) {
                    $tex .= pack "C3", 0, 0, 120;    # Dark blue
                }
                else {
                    $tex .= pack "C3", 240, 240, 240;    # White
                }

                # Make a round dot in the texture's alpha-channel.
                # Calculate distance to center (squared).
                my $t = ( $x - 64 ) * ( $x - 64 ) + ( $y - 64 ) * ( $y - 64 );

                if ( $t < $hole_size ) {
                    $tex .= pack "C", 255;    # The dot itself is opaque.
                }
                elsif ( $t < $hole_size + 100 ) {
                    $tex .= pack "C", 128;    # Give our dot an anti-aliased edge.
                }
                else {
                    $tex .= pack "C", 0;      # Outside of the dot, it's transparent.
                }
            }
        }

        $Tex_Pixels_oga = OpenGL::Array->new_scalar( GL_UNSIGNED_BYTE, $tex, length $tex );

        $Tex_Type   = GL_RGBA8;
        $Tex_Format = GL_RGBA;
        $Tex_Size   = GL_UNSIGNED_BYTE;
    }
    glBindTexture GL_TEXTURE_2D, $TextureID_image;

    # Use MipMap
    if ( $useMipMap ) {
        note "Using Mipmap\n";

        glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST_MIPMAP_LINEAR;
        glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_LINEAR;

        # The GLU library helps us build MipMaps for our texture.
        if ( my $gluerr = gluBuild2DMipmaps_c GL_TEXTURE_2D, $Tex_Type, $Tex_Width, $Tex_Height, $Tex_Format,
            $Tex_Size, $Tex_Pixels_oga->ptr )
        {
            diag sprintf "GLULib%s\n", gluErrorString $gluerr ;
            exit -1;
        }
    }

    # Use normal texture - Note: dimensions must be power of 2
    else {
        glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR;
        glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR;

        glTexImage2D_c GL_TEXTURE_2D, 0, $Tex_Type, $Tex_Width, $Tex_Height, 0, $Tex_Format, $Tex_Size,
          $Tex_Pixels_oga->ptr;
    }

    # Benchmarks for Image Loading
    if ( DO_TESTS && $hasIM ) {
        my $loops = 2;

        my $im  = Image::Magick->new;
        my $res = $im->Read( $Tex_File );
        die $res if $res;
        $im->Set( magick => 'RGBA', depth => 8 );
        $im->Negate( channel => 'alpha' );

        # Bench ImageToBlob
        my $start = time;
        for ( my $i = 0 ; $i < $loops ; $i++ ) {
            my ( $blob ) = $im->ImageToBlob;

            glTexImage2D_s GL_TEXTURE_2D, 0, GL_RGBA8, $Tex_Width, $Tex_Height, 0, GL_RGBA, GL_UNSIGNED_BYTE, $blob;
        }
        my $now = time;
        my $fps = $loops / ( $now - $start );
        note "ImageToBlob + glTexImage2D_s: $fps\n";

        # Bench GetPixels
        $start = time;
        for ( my $i = 0 ; $i < $loops ; $i++ ) {
            my @pixels = $im->GetPixels(
                map       => 'BGRA',
                width     => $Tex_Width,
                height    => $Tex_Height,
                normalize => 'false'
            );

            glTexImage2D_p GL_TEXTURE_2D, 0, $Tex_Type, $Tex_Width, $Tex_Height, 0, $Tex_Format, $Tex_Size, @pixels;
        }
        $now = time;
        $fps = $loops / ( $now - $start );
        note "GetPixels + glTexImage2D_p: $fps\n";

        # Bench OpenGL::Image
        if ( $hasIM_635 ) {
            my $start = time;
            for ( my $i = 0 ; $i < $loops ; $i++ ) {
                glTexImage2D_c GL_TEXTURE_2D, 0, $Tex_Type, $Tex_Width, $Tex_Height, 0, $Tex_Format, $Tex_Size,
                  $Tex_Pixels_oga->ptr;
            }
            my $now = time;
            my $fps = $loops / ( $now - $start );
            note "OpenGL::Image + glTexImage2D_c: $fps\n";
        }
    }

    # Build FBO texture
    if ( $hasFBO ) {
        note "Using FBOs\n";

        ( $FrameBufferID )  = glGenFramebuffers_p 1;
        ( $RenderBufferID ) = glGenRenderbuffers_p 1;

        glBindFramebufferEXT GL_FRAMEBUFFER_EXT, $FrameBufferID;
        glBindTexture GL_TEXTURE_2D,             $TextureID_FBO;

        # Initiate texture
        glTexImage2D_c GL_TEXTURE_2D, 0, $Tex_Type, $Tex_Width, $Tex_Height, 0, $Tex_Format, $Tex_Size, 0;
        glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR;
        glTexParameteri GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR;

        # Bind texture/frame/render buffers
        glFramebufferTexture2DEXT GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, $TextureID_FBO, 0;
        glBindRenderbufferEXT GL_RENDERBUFFER_EXT, $RenderBufferID;
        glRenderbufferStorageEXT GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT24_ARB, $Tex_Width, $Tex_Height;
        glFramebufferRenderbufferEXT GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT, GL_RENDERBUFFER_EXT, $RenderBufferID;

        # Test status
        note sprintf "FBO Status: %04X\n", glCheckFramebufferStatusEXT GL_RENDERBUFFER_EXT
          if DO_TESTS;
    }

    # Select active texture
    ourSelectTexture();

    glTexEnvf GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_DECAL;
}

sub ourSelectTexture {
    glBindTexture GL_TEXTURE_2D, $FBO_On ? $TextureID_FBO : $TextureID_image;
}

sub ourInitShaders {

    # Setup Vertex/Fragment Programs to render FBO texture

    if ( $hasShader ) {
        my $version = $OpenGL::Shader::VERSION;
        note "Using OpenGL::Shader v$version\n";
        my $types = OpenGL::Shader->GetTypes;
        my @types = keys %$types;
        note sprintf "This installation supports the following shader types: %s\n", join ',', @types;

        $Shader = OpenGL::Shader->new;
        if ( not $Shader ) {
            note "Unable to instantiate OpenGL::Shader\n";
            return;
        }

        my $type = $Shader->GetType;
        my $ext  = lc $type;

        my $stat = $Shader->LoadFiles( "fragment.$ext", "vertex.$ext" );
        if ( not $stat ) {
            my $ver = $Shader->GetVersion;
            note "Using OpenGL::Shader('$type') v$ver\n";
            return;
        }
        else {
            note "$stat\n";
        }
    }

    # Fall back to doing it manually
    elsif ( $hasFragProg ) {
        note "Using native OpenGL ARB Shader functions\n";
        ( $VertexProgID, $FragProgID ) = glGenProgramsARB_p 2;

        # NOP Vertex shader
        my $VertexProg = qq
    {!!ARBvp1.0
      PARAM center = program.local[0];
      PARAM xform[4] = {program.local[1..4]};
      TEMP vertexClip;

      # ModelView projection
      DP4 vertexClip.x, state.matrix.mvp.row[0], vertex.position;
      DP4 vertexClip.y, state.matrix.mvp.row[1], vertex.position;
      DP4 vertexClip.z, state.matrix.mvp.row[2], vertex.position;
      DP4 vertexClip.w, state.matrix.mvp.row[3], vertex.position;

      # Additional transform, via matrix variable
      DP4 vertexClip.x, vertexClip, xform[0];
      DP4 vertexClip.y, vertexClip, xform[1];
      DP4 vertexClip.z, vertexClip, xform[2];
      DP4 vertexClip.w, vertexClip, xform[3];

      #SUB result.position, vertexClip, center;
      MOV result.position, vertexClip;

      # Pass through color
      MOV result.color, vertex.color;

      # Pass through texcoords
      SUB result.texcoord[0], vertex.texcoord, center;
      END
    };

        glBindProgramARB GL_VERTEX_PROGRAM_ARB,     $VertexProgID;
        glProgramStringARB_p GL_VERTEX_PROGRAM_ARB, $VertexProg;

        if ( DO_TESTS ) {
            my $format = glGetProgramivARB_p GL_VERTEX_PROGRAM_ARB,
              GL_PROGRAM_FORMAT_ARB;    # does this even make sense? target seems wrong
            note sprintf "glGetProgramivARB_p format: '#%04X'\n", $format; # 34933 # glGetProgramivARB_p format: '#8875'

            my @params = glGetProgramEnvParameterdvARB_p GL_VERTEX_PROGRAM_ARB, 0;
            my $params = join ', ', @params;
            note "glGetProgramEnvParameterdvARB_p: $params\n";

            @params = glGetProgramEnvParameterfvARB_p GL_VERTEX_PROGRAM_ARB, 0;
            $params = join ', ', @params;
            note "glGetProgramEnvParameterfvARB_p: $params\n";

            my $vprog = glGetProgramStringARB_p GL_VERTEX_PROGRAM_ARB;
            note "Vertex Prog: $vprog\n";
        }

        # Lazy Metalic Fragment shader
        my $FragProg = qq
    {!!ARBfp1.0
      PARAM surfacecolor = program.local[5];
      TEMP color;
      MUL color, fragment.texcoord[0].y, 2.0;
      ADD color, 1.0, -color;
      ABS color, color;
      ADD color, 1.01, -color;  #Some cards have a rounding error
      MOV color.a, 1.0;
      MUL color, color, surfacecolor;
      MOV result.color, color;
      END
    };

        glBindProgramARB GL_FRAGMENT_PROGRAM_ARB,     $FragProgID;
        glProgramStringARB_p GL_FRAGMENT_PROGRAM_ARB, $FragProg;

        if ( DO_TESTS ) {
            my $fprog = glGetProgramStringARB_p GL_FRAGMENT_PROGRAM_ARB;
            note "Fragment Prog: $fprog\n";
        }
    }
}

# ------
# Routine which actually does the drawing

sub cbRenderScene {
    my $time = time;                                           # Quit if inactive
    my $time_to_exit = $idleSecsMax - ( $time - $idleTime );
    if ( $time_to_exit <= 0 ) {
        note "Idle timeout; completing test\n";
        ourCleanup();
        return quit( "render callback" );
    }

    my $buf;                                                   # For our strings.

    if ( $FBO_On and ( $FBO_On == 2 or not $FBO_rendered ) ) { # Animated Texture Rendering
        $FBO_rendered = 1;
        glBindFramebufferEXT GL_FRAMEBUFFER_EXT, $FrameBufferID;
        glPushMatrix;
        glTranslatef - 0.35, -0.48, -1.5;
        glRotatef $Teapot_Rot--, 0.0, 1.0, 0.0;
        glClearColor 0, 0, 0, 0;
        my $clears = GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT;
        glClear $clears;

        glPushAttrib GL_ENABLE_BIT;
        glEnable GL_DEPTH_TEST;

        # Run shader programs for texture.
        if ( $Shader ) {    # If installed, use OpenGL::Shader
            $Shader->Enable;
            $Shader->SetVector( 'center', 0.0, 0.0, 2.0, 0.0 );
            $Shader->SetMatrix( 'xform', $xform_oga );
            $Shader->SetVector( 'surfacecolor', 1.0, 0.5, 0.0, 1.0 );
        }
        elsif ( $hasFragProg ) {    # Otherwise, do it manually
            glEnable GL_VERTEX_PROGRAM_ARB;
            glEnable GL_FRAGMENT_PROGRAM_ARB;

            glProgramLocalParameter4fARB GL_VERTEX_PROGRAM_ARB, 0, 0.0, 0.0, 2.0, 0.0;

            glProgramLocalParameter4fvARB_c GL_VERTEX_PROGRAM_ARB, 1, $xform_oga->offset( 0 );
            glProgramLocalParameter4fvARB_c GL_VERTEX_PROGRAM_ARB, 2, $xform_oga->offset( 4 );
            glProgramLocalParameter4fvARB_c GL_VERTEX_PROGRAM_ARB, 3, $xform_oga->offset( 8 );
            glProgramLocalParameter4fvARB_c GL_VERTEX_PROGRAM_ARB, 4, $xform_oga->offset( 12 );

            glProgramLocalParameter4fARB GL_FRAGMENT_PROGRAM_ARB, 5, 1.0, 0.5, 0.0, 1.0;
        }

        glColor3f 1.0, 1.0, 1.0;

        glutWireTeapot 0.125;
        glBindFramebufferEXT GL_FRAMEBUFFER_EXT, 0;

        if ( $Shader ) {
            $Shader->Disable;
        }
        elsif ( $hasFragProg ) {
            glDisable GL_FRAGMENT_PROGRAM_ARB;
            glDisable GL_VERTEX_PROGRAM_ARB;
        }

        glPopAttrib;
        glPopMatrix;
    }
    ourSelectTexture();

    # Enables, disables or otherwise adjusts as
    # appropriate for our current settings.
    if ( $Texture_On ) {
        glEnable GL_TEXTURE_2D;
    }
    else {
        glDisable GL_TEXTURE_2D;
    }
    if ( $Light_On ) {
        glEnable GL_LIGHTING;
    }
    else {
        glDisable GL_LIGHTING;
    }
    if ( $Alpha_Add ) {
        glBlendFunc GL_SRC_ALPHA, GL_ONE;
    }
    else {
        glBlendFunc GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA;
    }
    if ( $Blend_On ) {    # If we're blending, we don't want z-buffering.
        glDisable GL_DEPTH_TEST;
    }
    else {
        glEnable GL_DEPTH_TEST;
    }

    glMatrixMode GL_MODELVIEW;    # Need to manipulate the ModelView matrix to move our model around.

    glLoadIdentity;               # Reset to 0,0,0; no rotation, no scaling.

    glTranslatef 0.0, 0.0, $Z_Off;    # Move the object back from the screen.

    glRotatef $X_Rot, 1.0, 0.0, 0.0;  # Rotate the calculated amount.
    glRotatef $Y_Rot, 0.0, 1.0, 0.0;

    my $clears = GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT;
    glClear $clears;                  # Clear the color and depth buffers.

    for ( my $i = 0 ; $i < scalar( @rainbow ) ; $i++ ) {    # Update Rainbow Cube Face
        $rainbow[$i] += $rainbow_inc[$i];
        if ( $rainbow[$i] < 0 ) {
            $rainbow[$i] = 0.0;
        }
        elsif ( $rainbow[$i] > 1 ) {
            $rainbow[$i] = 1.0;
        }
        else {
            next;
        }
        $rainbow_inc[$i] = -$rainbow_inc[$i];
    }

    if ( $hasVBO ) {
        glBindBufferARB GL_ARRAY_BUFFER_ARB, $ColorObjID;
        my $color_map_oga = glMapBufferARB_p GL_ARRAY_BUFFER_ARB, GL_WRITE_ONLY_ARB, GL_FLOAT;
        $color_map_oga->assign( $rainbow_offset, @rainbow );
        glUnmapBufferARB GL_ARRAY_BUFFER_ARB;
    }
    else {
        $colors_oga->assign( $rainbow_offset, @rainbow );
        glColorPointer_p 4, $colors_oga;
    }

    # Render cube
    glEnableClientState GL_VERTEX_ARRAY;
    glEnableClientState GL_NORMAL_ARRAY;
    glEnableClientState GL_COLOR_ARRAY;
    glEnableClientState GL_TEXTURE_COORD_ARRAY;

    for ( my $i = 0 ; $i < scalar( @indices ) ; $i += 4 ) {
        glDrawArrays GL_QUADS, $i, 4;
    }

    glDisableClientState GL_TEXTURE_COORD_ARRAY;
    glDisableClientState GL_COLOR_ARRAY;
    glDisableClientState GL_NORMAL_ARRAY;
    glDisableClientState GL_VERTEX_ARRAY;

    glLoadIdentity;    # Move back to the origin (for the text, below).

    glMatrixMode GL_PROJECTION;    # We need to change the projection matrix for the text rendering.

    glPushMatrix;                  # But we like our current view too; so we save it here.

    glLoadIdentity;                # Now we set up a new projection for the text.
    glOrtho 0, $Window_Width, 0, $Window_Height, -1.0, 1.0;

    glDisable GL_TEXTURE_2D;       # Lit or textured text looks awful.
    glDisable GL_LIGHTING;

    glDisable GL_DEPTH_TEST;       # We don't want depth-testing either.

    glColor4f 0.6, 1.0, 0.6, .75;  # But, for fun, let's make the text partially transparent too.

    $buf = sprintf "TIME TO EXIT: %.1fs", $time_to_exit;
    my $bufwidth = 6 * length $buf;
    glRasterPos2i $Window_Width - 4 - $bufwidth, 2;
    ourPrintString( GLUT_BITMAP_HELVETICA_12, $buf );

    # Render our various display mode settings.
    $buf = sprintf "Mode: %s", $TexModesStr[$Curr_TexMode];
    glRasterPos2i 2, 2;
    ourPrintString( GLUT_BITMAP_HELVETICA_12, $buf );

    $buf = sprintf "Alpha: %d", $Alpha_Add;
    glRasterPos2i 2, 14;
    ourPrintString( GLUT_BITMAP_HELVETICA_12, $buf );

    $buf = sprintf "Blend: %d", $Blend_On;
    glRasterPos2i 2, 26;
    ourPrintString( GLUT_BITMAP_HELVETICA_12, $buf );

    $buf = sprintf "Light: %d", $Light_On;
    glRasterPos2i 2, 38;
    ourPrintString( GLUT_BITMAP_HELVETICA_12, $buf );

    $buf = sprintf "Tex: %d", $Texture_On;
    glRasterPos2i 2, 50;
    ourPrintString( GLUT_BITMAP_HELVETICA_12, $buf );

    $buf = sprintf "FBO: %d", $FBO_On;
    glRasterPos2i 2, 62;
    ourPrintString( GLUT_BITMAP_HELVETICA_12, $buf );

    $buf = sprintf "Inset: %d", $Inset_On;
    glRasterPos2i 2, 74;
    ourPrintString( GLUT_BITMAP_HELVETICA_12, $buf );

    glTranslatef 6.0, $Window_Height - 14, 0.0;    # Now we want to render the calulated FPS at the top.
                                                   # To ease, simply translate up.  Note we're working in screen
                                                   # pixels in this projection.

    glColor4f 0.2, 0.2, 0.2, 0.75;                 # Make sure we can read the FPS section by first placing a
                                                   # dark, mostly opaque backdrop rectangle.

    glBegin GL_QUADS;
    glVertex3f 0.0,   -2.0, 0.0;
    glVertex3f 0.0,   12.0, 0.0;
    glVertex3f 140.0, 12.0, 0.0;
    glVertex3f 140.0, -2.0, 0.0;
    glEnd;

    glColor4f 0.9, 0.2, 0.2, .75;
    $buf = sprintf "FPS: %f F: %2d", $FrameRate, $FrameCount;
    glRasterPos2i 6, 0;
    ourPrintString( GLUT_BITMAP_HELVETICA_12, $buf );

    glPopMatrix;    # Done with this special projection matrix.  Throw it away.

    Capture( Inset => 1 ) if $Inset_On;    # Do Inset View

    glutSwapBuffers;                       # All done drawing.  Let's show it.

    $X_Rot += $X_Speed;                    # Now let's do the motion calculations.
    $Y_Rot += $Y_Speed;

    ourDoFPS();                            # And collect our statistics.
}

sub Capture {                              # Capture window
    my ( %params ) = @_;

    my ( $w ) = glutGet GLUT_WINDOW_WIDTH;
    my ( $h ) = glutGet GLUT_WINDOW_HEIGHT;

    my $attr = GL_ENABLE_BIT | GL_VIEWPORT_BIT | GL_TRANSFORM_BIT | GL_COLOR_BUFFER_BIT;
    glPushAttrib $attr;
    glDisable GL_LIGHTING;
    glDisable GL_FOG;
    glDisable GL_TEXTURE_2D;
    glDisable GL_DEPTH_TEST;
    glDisable GL_CULL_FACE;
    glDisable GL_STENCIL_TEST;

    glViewport 0, 0, $w, $h;
    glMatrixMode GL_PROJECTION;
    glPushMatrix;
    glLoadIdentity;
    eval { gluOrtho2D 0, $w, 0, $h; 1 } or $er++ or warn "Catched: $@";
    glMatrixMode GL_MODELVIEW;
    glPushMatrix;
    glLoadIdentity;

    glPixelZoom 1, 1;

    if ( $params{Save} ) {
        Save( $w, $h, $params{Save} );
    }
    elsif ( $params{Inset} ) {
        Inset( $w, $h );
    }

    glMatrixMode GL_PROJECTION;
    glPopMatrix;
    glMatrixMode GL_MODELVIEW;
    glPopMatrix;
    glPopAttrib;
}

sub Inset {    # Display inset
    my ( $w, $h ) = @_;

    my $Capture_X = int( ( $w - $Inset_Width ) / 2 );
    my $Capture_Y = int( ( $h - $Inset_Height ) / 2 );
    my $Inset_X = $w - ( $Inset_Width + 2 );
    my $Inset_Y = $h - ( $Inset_Height + 2 );

    if ( $hasIM_635 ) {    # Using OpenGL::Image and ImageMagick to read/modify/draw pixels
        my $frame = OpenGL::Image->new(
            engine => 'Magick',
            width  => $Inset_Width,
            height => $Inset_Height
        );
        die $@ if $@;
        my ( $fmt, $size ) = $frame->Get( 'gl_format', 'gl_type' );

        glReadPixels_c $Capture_X, $Capture_Y, $Inset_Width, $Inset_Height, $fmt, $size, $frame->Ptr;

        $frame->Sync;      # Do this before making native calls
        $frame->Native->Blur( radius => 2, sigma => 2 );    # For grins, use ImageMagick to modify the inset
        $frame->SyncOGA;                                    # Do this when done making native calls

        glRasterPos2f $Inset_X, $Inset_Y;
        glDrawPixels_c $Inset_Width, $Inset_Height, $fmt, $size, $frame->Ptr;
    }
    else {                                                  # Fastest approach
        my $len = $Inset_Width * $Inset_Height * 4;
        my $oga = OpenGL::Array->new( $len, GL_UNSIGNED_BYTE );

        glReadPixels_c $Capture_X, $Capture_Y, $Inset_Width, $Inset_Height, GL_RGBA, GL_UNSIGNED_BYTE, $oga->ptr;
        glRasterPos2f $Inset_X, $Inset_Y;
        glDrawPixels_c $Inset_Width, $Inset_Height, GL_RGBA, GL_UNSIGNED_BYTE, $oga->ptr;
    }
}

# Capture/save window
sub Save {
    my ( $w, $h, $file ) = @_;

    if ( $hasImage ) {
        my $frame = OpenGL::Image->new( width => $w, height => $h );
        my ( $fmt, $size ) = $frame->Get( 'gl_format', 'gl_type' );

        glReadPixels_c 0, 0, $w, $h, $fmt, $size, $frame->Ptr;
        $frame->Save( $file );
    }
    else {
        note "Need OpenGL::Image and ImageMagick 6.3.5 or newer for file capture!\n";
    }
}

# Cleanup routine
sub ourCleanup {
    note "Starting cleanup ...\n";

    # Disable app
    glutHideWindow;
    glutKeyboardUpFunc;
    glutKeyboardFunc;
    glutSpecialUpFunc;
    glutSpecialFunc;
    glutIdleFunc;
    glutReshapeFunc;

    ReleaseResources();

    # Now you can destroy window
    if ( defined $gameMode ) {
        note "Leaving game mode.\n";
        glutLeaveGameMode;
    }
    else {
        note "Destroying window.\n";
        glutDestroyWindow $Window_ID ;
    }
    undef $Window_ID;
    note "Cleanup completed.\n";
}

sub ReleaseResources {
    return if not defined $Window_ID;

    if ( $hasFBO ) {    # Release resources
        glBindRenderbufferEXT GL_RENDERBUFFER_EXT, 0;
        glBindFramebufferEXT GL_FRAMEBUFFER_EXT,   0;

        glDeleteRenderbuffersEXT_p $RenderBufferID if $RenderBufferID;
        glDeleteFramebuffersEXT_p $FrameBufferID   if $FrameBufferID;
    }

    if ( $Shader ) {
        undef $Shader;
    }
    elsif ( $hasFragProg ) {
        glBindProgramARB GL_VERTEX_PROGRAM_ARB, 0;
        glDeleteProgramsARB_p $VertexProgID if $VertexProgID;

        glBindProgramARB GL_FRAGMENT_PROGRAM_ARB, 0;
        glDeleteProgramsARB_p $FragProgID if $FragProgID;
    }

    if ( $hasVBO ) {
        glBindBufferARB GL_ARRAY_BUFFER_ARB, 0;
        glDeleteBuffersARB_p $VertexObjID   if $VertexObjID;
        glDeleteBuffersARB_p $NormalObjID   if $NormalObjID;
        glDeleteBuffersARB_p $ColorObjID    if $ColorObjID;
        glDeleteBuffersARB_p $TexCoordObjID if $TexCoordObjID;

        glBindBufferARB GL_ELEMENT_ARRAY_BUFFER_ARB, 0;
        glDeleteBuffersARB_p $IndexObjID if $IndexObjID;
    }

    glDeleteTextures_p $TextureID_image, $TextureID_FBO;
}

# ------
# Callback function called when a normal $key is pressed.

sub cbKeyPressed {
    my $key = shift;
    my $c   = uc chr $key;
    if ( $key == 27 or $c eq 'Q' ) {
        ourCleanup();
        return quit( "key press callback" );
    }
    elsif ( $c eq 'B' ) {
        $Blend_On = not $Blend_On;
        if ( not $Blend_On ) {
            glDisable GL_BLEND;
        }
        else {
            glEnable GL_BLEND;
        }
    }
    elsif ( $c eq 'K' ) {
        glutLeaveMainLoop if OpenGL::_have_freeglut();    # ignore keypress if not FreeGLUT
    }
    elsif ( $c eq 'L' ) {
        $Light_On = not $Light_On;
    }
    elsif ( $c eq 'M' ) {
        if ( ++$Curr_TexMode > 3 ) {
            $Curr_TexMode = 0;
        }
        glTexEnvi GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, $TexModes[$Curr_TexMode];
    }
    elsif ( $c eq 'T' ) {
        $Texture_On = not $Texture_On;
    }
    elsif ( $c eq 'A' ) {
        $Alpha_Add = not $Alpha_Add;
    }
    elsif ( $c eq 'F' && $hasFBO ) {
        $FBO_On = ( $FBO_On + 1 ) % 3;
        ourSelectTexture();
    }
    elsif ( $c eq 'I' ) {
        $Inset_On = not $Inset_On;
    }
    elsif ( $c eq 'S' or $key == 32 ) {
        $X_Speed = $Y_Speed = 0;
    }
    elsif ( $c eq 'R' ) {
        $X_Speed = -$X_Speed;
        $Y_Speed = -$Y_Speed;
    }
    elsif ( $c eq 'G' ) {
        $Fullscreen_On = not $Fullscreen_On;
        if ( $Fullscreen_On ) {
            $Window_State  = glpFullScreen;
            $Window_Width  = $Window_State->{w};
            $Window_Height = $Window_State->{h};
        }
        else {
            glpRestoreScreen $Window_State ;
        }
    }
    elsif ( $c eq 'C' && $hasImage ) {
        Capture( Save => 'capture.tga' );
    }
    else {
        note sprintf "KP: No action for %d.\n", $key;
    }

    $idleTime = time;
}

# ------
# Callback Function called when a special $key is pressed.

sub cbSpecialKeyPressed {
    my $key = shift;

    if ( $key == GLUT_KEY_PAGE_UP ) {
        $Z_Off -= 0.05;
    }
    elsif ( $key == GLUT_KEY_PAGE_DOWN ) {
        $Z_Off += 0.05;
    }
    elsif ( $key == GLUT_KEY_UP ) {
        $X_Speed -= 0.01;
    }
    elsif ( $key == GLUT_KEY_DOWN ) {
        $X_Speed += 0.01;
    }
    elsif ( $key == GLUT_KEY_LEFT ) {
        $Y_Speed -= 0.01;
    }
    elsif ( $key == GLUT_KEY_RIGHT ) {
        $Y_Speed += 0.01;
    }
    else {
        note sprintf "SKP: No action for %d.\n", $key;
    }

    $idleTime = time;
}

# ------
# Callback function called for key-up events.

sub cbKeyUp {
    my ( $key ) = @_;
    my $mod = GetKeyModifier();
    note "Key up: $key w/ $mod\n" if $mod;
}

# ------
# Callback function called for special key-up events.

sub cbSpecialKeyUp {
    my ( $key ) = @_;
    my $mod = GetKeyModifier();
    note "Special Key up: $key w/ $mod\n" if $mod;
}

# ------
# Callback function called for handling mouse clicks.

sub cbMouseClick {
    my ( $button, $state, $x, $y ) = @_;

    if ( $button == GLUT_LEFT_BUTTON ) {
        note "Left";
    }
    elsif ( $button == GLUT_MIDDLE_BUTTON ) {
        note "Middle";
    }
    elsif ( $button == GLUT_RIGHT_BUTTON ) {
        note "Right";
    }
    else {
        note "Unknown";
    }
    note " mouse button, ";

    if ( $state == GLUT_DOWN ) {
        note "DOWN";
    }
    elsif ( $state == GLUT_UP ) {
        note "UP";
    }
    else {
        note "State UNKNOWN";
    }

    my $mod = GetKeyModifier();
    note " w/ $mod" if $mod;
    note ": $x, $y\n";

    # Example of using GLU to determine 3D click points
    if ( $state == GLUT_UP ) {
        note "\n";

        glGetDoublev_c GL_MODELVIEW_MATRIX, $mm_oga->ptr;
        my @model = $mm_oga->retrieve( 0, 16 );

        glGetDoublev_c GL_PROJECTION_MATRIX, $pm_oga->ptr;
        my @projection = $pm_oga->retrieve( 0, 16 );

        glGetIntegerv_c GL_VIEWPORT, $vp_oga->ptr;
        my @viewport = $vp_oga->retrieve( 0, 4 );

        note "Model Matrix:      $model[0], $model[1], $model[2], $model[3]\n"
          . "                   $model[4], $model[5], $model[6], $model[7]\n"
          . "                   $model[8], $model[9], $model[10], $model[11]\n"
          . "                   $model[12], $model[13], $model[14], $model[15]\n"
          . "Projection Matrix: $projection[0], $projection[1], $projection[2], $projection[3]\n"
          . "                   $projection[4], $projection[5], $projection[6], $projection[7]\n"
          . "                   $projection[8], $projection[9], $projection[10], $projection[11]\n"
          . "                   $projection[12], $projection[13], $projection[14], $projection[15]\n"
          . "Viewport: $viewport[0], $viewport[1], $viewport[2], $viewport[3]\n" . "\n";

        my @point = gluUnProject_p    #
          $x, $y, 0,                  # Cursor point
          @model,                     # Model Matrix
          @projection,                # Projection Matrix
          @viewport;                  # Viewport
        note "Model point: $point[0], $point[1], $point[2]\n";

        #    @point = gluProject_p(@point,	# Model point
        #      @model,				# Model Matrix
        #      @projection,			# Projection Matrix
        #      @viewport);			# Viewport
        #    print "Window point: $point[0], $point[1], $point[2]\n";
        note "\n";
    }

    $idleTime = time;
}

sub GetKeyModifier {
    my %key_mods = (
        GLUT_ACTIVE_SHIFT => "SHIFT",
        GLUT_ACTIVE_CTRL  => "CTRL",
        GLUT_ACTIVE_ALT   => "ALT"
    );
    return $key_mods{ +glutGetModifiers };
}

# ------
# Callback routine executed whenever our window is resized.  Lets us
# request the newly appropriate perspective projection matrix for
# our needs.  Try removing the gluPerspective() call to see what happens.

sub cbResizeScene {
    my ( $Width, $Height ) = @_;

    $Height = 1 if $Height == 0;    # Let's not core dump, no matter what.

    glViewport 0, 0, $Width, $Height;

    glMatrixMode GL_PROJECTION;
    glLoadIdentity;
    gluPerspective 45.0, $Width / $Height, 0.1, 100.0;

    glMatrixMode GL_MODELVIEW;

    $Window_Width  = $Width;
    $Window_Height = $Height;

    $idleTime = time;
}

sub cbClose {
    my ( $wid ) = @_;
    note "User has closed window: \#$wid\n";
    ReleaseResources();
}

# this is a little complicated
# Using freeglut, doing a straight exit crashes on some systems, mostly observed
# on windows, likely due to thread issues.
# However on non-freeglut systems the proper way of using glutLeaveMainLoop is
# not available.
# So the proper one needs to be chosen.
# However while exit exits the thread, glutLeaveMainLoop only sets a flag for
# the event loop, thus we must take care to return when using it. Additionally
# any use of quit() ALSO needs to return.
#
#   return quit();

sub quit {
    my ( $context ) = @_;
    $context ||= "<unknown context>";
    note "Exiting in $context using ";
    if ( OpenGL::_have_freeglut() ) {
        note "glutLeaveMainLoop (freeglut)\n";
        glutLeaveMainLoop;
        return;
    }
    note "perl exit(0)\n";
    exit 0;
}

__END__
