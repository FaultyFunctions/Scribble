/// @description Creates, and returns, a Scribble JSON, and its vertex buffer, built from a string
///
/// @param string
/// @param [box_width]
/// @param [font]
/// @param [line_halign]
/// @param [colour]
/// @param [line_height]

var _timer = get_timer();

var _str              = argument[0];
var _width_limit      = ((argument_count<2) || (argument[1]==undefined))? 9999999999                        : argument[1];
var _def_font         = ((argument_count<3) || (argument[2]==undefined))? global.__scribble_default_font    : argument[2];
var _def_halign       = ((argument_count<4) || (argument[3]==undefined))? fa_left                           : argument[3];
var _def_colour       = ((argument_count<5) || (argument[4]==undefined))? c_white                           : argument[4];
var _line_min_height  = ((argument_count<6) || (argument[5]==undefined))? undefined                         : argument[5];

//Find the default font's space width
var _font_glyphs_map = global.__scribble_glyphs_map[? _def_font ];
var _array = _font_glyphs_map[? " " ];
var _def_space_width = _array[ __E_SCRIBBLE_GLYPH.W ];

//Find the default line minimum height if not specified
if ( _line_min_height == undefined )
{
    var _font_glyphs_map = global.__scribble_glyphs_map[? _def_font ];
    var _array = _font_glyphs_map[? " " ];
    _line_min_height = _array[ __E_SCRIBBLE_GLYPH.H ];
}

//Strip out weird newlines
if ( SCRIBBLE_HASH_NEWLINE ) _str = string_replace_all( _str, "#", "\n" );
_str = string_replace_all( _str, "\n\r", "\n" );
_str = string_replace_all( _str, "\r\n", "\n" );
_str = string_replace_all( _str,   "\n", "\n" );
_str = string_replace_all( _str,  "\\n", "\n" );
_str = string_replace_all( _str,  "\\r", "\n" );



#region Break down string into sections using a buffer

var _separator_list  = ds_list_create();
var _position_list   = ds_list_create();
var _parameters_list = ds_list_create();
var _buffer_size = string_byte_length( _str )+1;
var _buffer = buffer_create( _buffer_size, buffer_grow, 1 );

buffer_write( _buffer, buffer_string, _str );
buffer_seek( _buffer, buffer_seek_start, 0 );

var _in_command_tag = false;
var _i = 0;
repeat( _buffer_size )
{
    var _value = buffer_peek( _buffer, _i, buffer_u8 );
    
    if ( _value == 0 ) //<null>
    {
        ds_list_add( _separator_list, "" );
        ds_list_add( _position_list, _i );
        break;
    }
    
    if ( _in_command_tag )
    {
        if ( _value == 93 ) || ( _value == 124 ) // ] or |
        {
            if ( _value == 93 ) _in_command_tag = false;
            buffer_poke( _buffer, _i, buffer_u8, 0 );
            ds_list_add( _separator_list, _value );
            ds_list_add( _position_list, _i );
        }
    }
    else
    {
        if ( _value == 10 ) || ( _value == 32 ) || ( _value == 91 ) //\n or <space> or [
        {
            if ( _value == 91 ) _in_command_tag = true;
            buffer_poke( _buffer, _i, buffer_u8, 0 );
            ds_list_add( _separator_list, _value );
            ds_list_add( _position_list, _i );
        }
    }
    
    ++_i;
}

#endregion



#region Create the JSON

//Create data structures
var _json = ds_map_create();

//Input values
_json[? "string"         ] = _str;
_json[? "default font"   ] = _def_font;
_json[? "default colour" ] = _def_colour;
_json[? "default halign" ] = _def_halign;
_json[? "width limit"    ] = _width_limit;
_json[? "line height"    ] = _line_min_height;

//Main data structure for text storage
var _text_root_list = ds_list_create();
ds_map_add_list( _json, "lines list", _text_root_list );

//Box alignment and dimensions
_json[? "halign" ] = fa_left;
_json[? "valign" ] = fa_top;
_json[? "width"  ] = 0;
_json[? "height" ] = 0;
_json[? "left"   ] = 0;
_json[? "top"    ] = 0;
_json[? "right"  ] = 0;
_json[? "bottom" ] = 0;

//Stats
_json[? "length" ] = 0;
_json[? "lines"  ] = 0;
_json[? "words"  ] = 0;

//Typewriter
_json[? "typewriter direction"  ] = 0;
_json[? "typewriter speed"      ] = SCRIBBLE_DEFAULT_TYPEWRITER_SPEED;
_json[? "typewriter position"   ] = 0;
_json[? "typewriter method"     ] = SCRIBBLE_DEFAULT_TYPEWRITER_METHOD;
_json[? "typewriter smoothness" ] = SCRIBBLE_DEFAULT_TYPEWRITER_SMOOTHNESS;

//Vertex buffer/shader values
var _vbuff_list = ds_list_create();
ds_map_add_list( _json, "vertex buffer list", _vbuff_list );

//Animation effects
_json[? "wave size"            ] = SCRIBBLE_DEFAULT_WAVE_SIZE;
_json[? "shake size"           ] = SCRIBBLE_DEFAULT_SHAKE_SIZE;
_json[? "rainbow weight"       ] = SCRIBBLE_DEFAULT_RAINBOW_WEIGHT;

//Character fade
_json[? "char fade t"          ] = 1;
_json[? "char fade smoothness" ] = 0;

//Line fade
_json[? "line fade t"          ] = 1;
_json[? "line fade smoothness" ] = 0;

//Event triggering
var _events_character_list = ds_list_create();
var _events_name_list      = ds_list_create();
var _events_data_list      = ds_list_create();
ds_map_add_list( _json, "events character list", _events_character_list );
ds_map_add_list( _json, "events name list"     , _events_name_list      );
ds_map_add_list( _json, "events data list"     , _events_data_list      );
ds_map_add_list( _json, "events triggered list", ds_list_create()       );
ds_map_add_map(  _json, "events triggered map" , ds_map_create()        );
ds_map_add_map(  _json, "events value map"     , ds_map_create()        );
ds_map_add_map(  _json, "events changed map"   , ds_map_create()        );
ds_map_add_map(  _json, "events previous map"  , ds_map_create()        );
ds_map_add_map(  _json, "events different map" , ds_map_create()        );

#endregion



#region Parser

#region Initial parser state
var _text_x = 0;
var _text_y = 0;

var _map              = noone;
var _word_array       = noone;
var _line_array       = noone;
var _line_words_array = noone;
var _line_length      = 0;
var _line_max_height  = _line_min_height;

var _text_font      = _def_font;
var _text_colour    = _def_colour;
var _text_halign    = _def_halign;
var _text_rainbow   = false;
var _text_shake     = false;
var _text_wave      = false;

var _font_line_height = _line_min_height;
var _font_space_width = _def_space_width;
#endregion

//Iterate over the entire string...
var _sep_char = 0;
var _in_command_tag = false;
var _new_word = false;

var _separator_count = ds_list_size( _separator_list );
for( var _i = 0; _i < _separator_count; _i++ )
{
    var _sep_prev_char = _sep_char;
        _sep_char = _separator_list[| _i ];
    
    if ( _new_word ) _word_array[@ __E_SCRIBBLE_WORD.NEXT_SEPARATOR ] = _sep_char;
    _new_word = false;
    
    var _input_substr = buffer_read( _buffer, buffer_string );
    var _substr = _input_substr;
    
    #region Reset state
    var _skip          = false;
    var _force_newline = false;
    var _new_word      = false;
    
    var _substr_width       = 0;
    var _substr_height      = 0;
    var _substr_length      = string_length( _input_substr );
    var _substr_sprite      = noone;
    var _substr_image       = undefined;
    
    var _first_character = ( is_array( _line_words_array ) && (array_length_1d( _line_words_array ) <= 1) );
    #endregion
    
    if ( _in_command_tag )
    {
        #region Command Handling
        ds_list_add( _parameters_list, _input_substr );
        
        if ( _sep_char != 93 ) // ]
        {
            continue;
        }
        else
        {
            _substr_length = 0;
            
            switch( _parameters_list[| 0 ] )
            {
                #region Reset formatting
                case "":
                    _text_font      = _def_font;
                    _text_colour    = _def_colour;
                
                    _text_rainbow   = false;
                    _text_shake     = false;
                    _text_wave      = false;
            
                    _font_line_height = _line_min_height;
                    _font_space_width = _def_space_width;
                    _skip = true;
                break;
                #endregion
                
                #region Events
                case "event":
                case "ev":
                    var _parameter_count = ds_list_size( _parameters_list );
                    if ( _parameter_count <= 1 )
                    {
                        show_error( "Not enough parameters for event!", false );
                        _skip = true;
                    }
                    else
                    {
                        var _name = _parameters_list[| 1];
                        var _data = array_create( _parameter_count-2, "" );
                        for( var _j = 2; _j < _parameter_count; _j++ ) _data[ _j-2 ] = _parameters_list[| _j ];
                
                        ds_list_add( _events_character_list, _json[? "length" ] );
                        ds_list_add( _events_name_list     , _name              );
                        ds_list_add( _events_data_list     , _data              );
                    }
                    
                    _skip = true;
                break;
                #endregion
                
                #region Rainbow
                case "rainbow":
                    _text_rainbow = true;
                    _skip = true;
                break;
                case "/rainbow":
                    _text_rainbow = false;
                    _skip = true;
                break;
                #endregion
                
                #region Shake
                case "shake":
                    _text_shake = true;
                    _skip = true;
                break;
                case "/shake":
                    _text_shake = false;
                    _skip = true;
                break;
                #endregion
                
                #region Wave
                case "wave":
                    _text_wave = true;
                    _skip = true;
                break;
                case "/wave":
                    _text_wave = false;
                    _skip = true;
                break;
                #endregion
                
                #region Font Alignment
                case "fa_left":
                    _text_halign = fa_left;
                    _substr = "";
                    
                    if ( _first_character )
                    {
                        if ( _line_array != noone ) _line_array[@ __E_SCRIBBLE_LINE.HALIGN ] = _text_halign;
                    }
                    else
                    {
                        _force_newline = true;
                    }
                break;
                
                case "fa_right":
                    _text_halign = fa_right;
                    _substr = "";
                    
                    if ( _first_character )
                    {
                        if ( _line_array != noone ) _line_array[@ __E_SCRIBBLE_LINE.HALIGN ] = _text_halign;
                    }
                    else
                    {
                        _force_newline = true;
                    }
                break;
                
                case "fa_center":
                case "fa_centre":
                    _text_halign = fa_center;
                    _substr = "";
                    
                    if ( _first_character )
                    {
                        if ( _line_array != noone ) _line_array[@ __E_SCRIBBLE_LINE.HALIGN ] = _text_halign;
                    }
                    else
                    {
                        _force_newline = true;
                    }
                break;
                #endregion
                
                default:
                    if ( ds_map_exists( global.__scribble_glyphs_map, _parameters_list[| 0] ) )
                    {
                        #region Change font
                        _text_font = _parameters_list[| 0];
                        
                        var _font_glyphs_map = global.__scribble_glyphs_map[? _text_font ];
                        var _array = _font_glyphs_map[? " " ];
                        _font_space_width = _array[ __E_SCRIBBLE_GLYPH.W ];
                        
                        var _font_glyphs_map = global.__scribble_glyphs_map[? _text_font ];
                        var _array = _font_glyphs_map[? " " ];
                        _font_line_height = _array[ __E_SCRIBBLE_GLYPH.H ];
                        
                        _skip = true;
                        #endregion
                    }
                    else
                    {
                        var _asset = asset_get_index( _parameters_list[| 0] );
                        if ( _asset >= 0 ) && ( asset_get_type( _parameters_list[| 0] ) == asset_sprite )
                        {
                            #region Sprites
                            
                            _substr_sprite = _asset;
                            _substr_width  = sprite_get_width(  _substr_sprite );
                            _substr_height = sprite_get_height( _substr_sprite );
                            _substr_length = 1;
                
                            if ( ds_list_size( _parameters_list ) <= 1 ) _parameters_list[| 1] = "0";
                            
                            _substr_image = real( _parameters_list[| 1] );
                            
                            #endregion
                        }
                        else
                        {
                            #region Colours
                            var _colour = global.__scribble_colours[? _parameters_list[| 0] ]; //Test if it's a colour
                            if ( _colour != undefined )
                            {
                                _text_colour = _colour;
                            }
                            else //Test if it's a hexcode
                            {     
                                var _colour_string = string_upper( _parameters_list[| 0] );
                                if ( string_length( _colour_string ) <= 7 ) && ( string_copy( _colour_string, 1, 1 ) == "$" )
                                {
                                    var _hex = "0123456789ABCDEF";
                                    var _red   = max( string_pos( string_copy( _colour_string, 3, 1 ), _hex )-1, 0 ) + ( max( string_pos( string_copy( _colour_string, 2, 1 ), _hex )-1, 0 ) << 4 );
                                    var _green = max( string_pos( string_copy( _colour_string, 5, 1 ), _hex )-1, 0 ) + ( max( string_pos( string_copy( _colour_string, 4, 1 ), _hex )-1, 0 ) << 4 );
                                    var _blue  = max( string_pos( string_copy( _colour_string, 7, 1 ), _hex )-1, 0 ) + ( max( string_pos( string_copy( _colour_string, 6, 1 ), _hex )-1, 0 ) << 4 );
                                    _text_colour = make_colour_rgb( _red, _green, _blue );     
                                }
                            }
                            _skip = true;
                            #endregion
                        }
                    }
                break;
            }
            
            ds_list_clear( _parameters_list );
            _in_command_tag = false;
            
            if ( _skip )
            {
                _skip = false;
                continue;
            }
        }
        #endregion
    }
    else
    {
        //Find the substring width
        var _font_glyphs_map = global.__scribble_glyphs_map[? _text_font ];

        var _x            = 0;
        var _substr_width = 0;

        var _length = string_length( _substr );
        for( var _j = 1; _j <= _length-1; _j++ ) {
    
            var _char = string_copy( _substr, _j, 1 );
            if ( ord( _char ) == 10 ) _x = 0;
    
            var _array = _font_glyphs_map[? _char ];
            if ( _array == undefined ) continue;
    
            _x += _array[ __E_SCRIBBLE_GLYPH.SHF ];
            _substr_width = max( _substr_width, _x );
    
        }

        var _char = string_copy( _substr, _length, 1 );
        var _array = _font_glyphs_map[? _char ];
        if ( _array != undefined ) {
            _x += _array[ __E_SCRIBBLE_GLYPH.DX ] + _array[ __E_SCRIBBLE_GLYPH.W ];
            _substr_width = max( _substr_width, _x );
        }
        
        //Choose the height of a space for the substring's height
        var _font_glyphs_map = global.__scribble_glyphs_map[? _text_font ];
        var _array = _font_glyphs_map[? " " ];
        _substr_height = _array[ __E_SCRIBBLE_GLYPH.H ];
    }
    
    #region Position and store word
        
    //If we've run over the maximum width of the string
    if ( _substr_width + _text_x > _width_limit ) || ( _line_array == noone ) || ( _sep_prev_char == 10 ) || ( _force_newline )
    {
        if ( _line_array != noone )
        {
            _line_array[@ __E_SCRIBBLE_LINE.WIDTH  ] = _text_x;
            _line_array[@ __E_SCRIBBLE_LINE.HEIGHT ] = _line_max_height;
            
            _text_x = 0;
            _text_y += _line_max_height;
            _line_length = 0;
            
            _line_max_height = _line_min_height;
        }
            
        if ( _word_array != noone )
        {
            // _word_array still holds the previous word
            var _next_separator = _word_array[ __E_SCRIBBLE_WORD.NEXT_SEPARATOR ];
            if ( _next_separator == 32 ) || ( _next_separator == 91 ) // <space> or [
            {
                _word_array[@ __E_SCRIBBLE_WORD.WIDTH ] -= _font_space_width; //If the previous separation character was whitespace, correct the length of the previous word
                _line_array[@ __E_SCRIBBLE_LINE.WIDTH ] -= _font_space_width; //...and the previous line
            }
        }
        
        var _line_array = array_create( __E_SCRIBBLE_LINE.__SIZE, 0 );
        
        var _line_words_array = array_create( 0, 0 );
        _line_array[ __E_SCRIBBLE_LINE.X      ] = 0;
        _line_array[ __E_SCRIBBLE_LINE.Y      ] = _text_y;
        _line_array[ __E_SCRIBBLE_LINE.WIDTH  ] = 0;
        _line_array[ __E_SCRIBBLE_LINE.HEIGHT ] = _line_min_height;
        _line_array[ __E_SCRIBBLE_LINE.LENGTH ] = 0;
        _line_array[ __E_SCRIBBLE_LINE.HALIGN ] = _text_halign;
        _line_array[ __E_SCRIBBLE_LINE.WORDS  ] = _line_words_array;
        
        ds_list_add( _text_root_list, _line_array );
    }
    
    if ( !_force_newline ) && ( _substr != "" )
    {
        _line_max_height = max( _line_max_height, _substr_height );
        
        //Add a new word
        _new_word = true;
        var _word_array = array_create( __E_SCRIBBLE_WORD.__SIZE, 0 );
        _word_array[ __E_SCRIBBLE_WORD.X              ] = _text_x;
        _word_array[ __E_SCRIBBLE_WORD.Y              ] = 0;
        _word_array[ __E_SCRIBBLE_WORD.WIDTH          ] = _substr_width;
        _word_array[ __E_SCRIBBLE_WORD.HEIGHT         ] = _substr_height;
        _word_array[ __E_SCRIBBLE_WORD.VALIGN         ] = fa_middle;
        _word_array[ __E_SCRIBBLE_WORD.STRING         ] = _substr;
        _word_array[ __E_SCRIBBLE_WORD.INPUT_STRING   ] = _input_substr;
        _word_array[ __E_SCRIBBLE_WORD.SPRITE         ] = _substr_sprite;
        _word_array[ __E_SCRIBBLE_WORD.IMAGE          ] = _substr_image;
        _word_array[ __E_SCRIBBLE_WORD.LENGTH         ] = _substr_length; //Include the separator character!
        _word_array[ __E_SCRIBBLE_WORD.FONT           ] = _text_font;
        _word_array[ __E_SCRIBBLE_WORD.COLOUR         ] = _text_colour;
        _word_array[ __E_SCRIBBLE_WORD.RAINBOW        ] = _text_rainbow;
        _word_array[ __E_SCRIBBLE_WORD.SHAKE          ] = _text_shake;
        _word_array[ __E_SCRIBBLE_WORD.WAVE           ] = _text_wave;
        _word_array[ __E_SCRIBBLE_WORD.NEXT_SEPARATOR ] = "";
        
        //Add the word to the line list
        _line_words_array[@ array_length_1d(_line_words_array) ] = _word_array;
    }
    
    _text_x += _substr_width;
    if ( _sep_char == 32 ) _text_x += _font_space_width; //Add spacing if the separation character is a space
    if ( (_sep_char == 32) && _new_word && (_substr != "") ) _word_array[@ __E_SCRIBBLE_WORD.WIDTH ] += _font_space_width;
    #endregion
    
    if ( _sep_char == 91 ) _in_command_tag = true; // [
    
    _line_array[@ __E_SCRIBBLE_LINE.LENGTH ] += _substr_length;
    if ( _substr_length > 0 ) ++_json[? "words" ];
    _json[? "length" ] += _substr_length;
}

//Finish defining the last line
_line_array[@ __E_SCRIBBLE_LINE.WIDTH  ] = _text_x;
_line_array[@ __E_SCRIBBLE_LINE.HEIGHT ] = _line_max_height;
_json[? "lines" ] = ds_list_size( _json[? "lines list" ] );
#endregion



#region Set box width/height and adjust line positions

//Textbox width and height
var _lines_size = ds_list_size( _text_root_list );

var _textbox_width = 0;
for( var _i = 0; _i < _lines_size; _i++ )
{
    var _line_array = _text_root_list[| _i ];
    _textbox_width = max( _textbox_width, _line_array[ __E_SCRIBBLE_LINE.WIDTH ] );
}

var _line_array = _text_root_list[| _lines_size - 1 ];
var _textbox_height = _line_array[ __E_SCRIBBLE_LINE.Y ] + _line_array[ __E_SCRIBBLE_LINE.HEIGHT ];
  
_json[? "width"  ] = _textbox_width;
_json[? "height" ] = _textbox_height;

//Adjust word positions
for( var _line = 0; _line < _lines_size; _line++ )
{
    var _line_array = _text_root_list[| _line ];
    switch( _line_array[ __E_SCRIBBLE_LINE.HALIGN ] )
    {
        case fa_left:
            _line_array[@ __E_SCRIBBLE_LINE.X ] = 0;
        break;
        case fa_center:
            _line_array[@ __E_SCRIBBLE_LINE.X ] += (_textbox_width - _line_array[ __E_SCRIBBLE_LINE.WIDTH ]) div 2;
        break;
        case fa_right:
            _line_array[@ __E_SCRIBBLE_LINE.X ] += _textbox_width - _line_array[ __E_SCRIBBLE_LINE.WIDTH ];
        break;
    }
    
    var _line_height     = _line_array[ __E_SCRIBBLE_LINE.HEIGHT ];
    var _line_word_array = _line_array[ __E_SCRIBBLE_LINE.WORDS  ];
    
    var _word_count = array_length_1d( _line_word_array );
    for( var _word = 0; _word < _word_count; _word++ )
    {
        var _word_array = _line_word_array[ _word ];
        
        switch( _word_array[ __E_SCRIBBLE_WORD.VALIGN ] )
        {
            case fa_top:
                _word_array[@ __E_SCRIBBLE_WORD.Y ] = 0;
            break;
            case fa_middle:
                _word_array[@ __E_SCRIBBLE_WORD.Y ] = ( _line_height - _word_array[ __E_SCRIBBLE_WORD.HEIGHT ] ) div 2;
            break;
            case fa_bottom:
                _word_array[@ __E_SCRIBBLE_WORD.Y ] = _line_height - _word_array[ __E_SCRIBBLE_WORD.HEIGHT ];
            break;
        }
    }
}

scribble_box_alignment( _json );

#endregion



buffer_delete( _buffer );
ds_list_destroy( _separator_list  );
ds_list_destroy( _position_list   );
ds_list_destroy( _parameters_list );



#region Build the vertex buffer

var _json_offset_x = _json[? "left" ];
var _json_offset_y = _json[? "top"  ];
var _vbuff_list    = _json[? "vertex buffer list" ];

var _texture_to_vbuff_map = ds_map_create();

var _previous_font = "";
var _previous_texture = -1;
var _text_char = 0;
var _max_char = _json[? "length" ]-1;

var _lines = _json[? "lines list" ];
var _lines_size = ds_list_size( _lines );
var _line = 0;
repeat( _lines_size )
{
    var _line_pc = _line / _lines_size;
    
    var _line_array = _lines[| _line ];
    var _line_l = _line_array[ __E_SCRIBBLE_LINE.X ] + _json_offset_x;
    var _line_t = _line_array[ __E_SCRIBBLE_LINE.Y ] + _json_offset_y;
    
    var _line_word_array = _line_array[ __E_SCRIBBLE_LINE.WORDS ];
    var _words_count = array_length_1d( _line_word_array );
    var _word = 0;
    repeat( _words_count )
    {
        var _word_array = _line_word_array[ _word ];
        var _word_l = _word_array[ __E_SCRIBBLE_WORD.X      ] + _line_l;
        var _word_t = _word_array[ __E_SCRIBBLE_WORD.Y      ] + _line_t;
        var _sprite = _word_array[ __E_SCRIBBLE_WORD.SPRITE ];
        
        if ( _sprite != noone )
        {
            #region Add a sprite
            
            _previous_font = "";
            
            var _char_pc     = _text_char / _max_char;
            var _colour      = _word_array[ __E_SCRIBBLE_WORD.COLOUR  ];
            var _rainbow     = _word_array[ __E_SCRIBBLE_WORD.RAINBOW ];
            var _shake       = _word_array[ __E_SCRIBBLE_WORD.SHAKE   ];
            var _wave        = _word_array[ __E_SCRIBBLE_WORD.WAVE    ];
            var _image       = _word_array[ __E_SCRIBBLE_WORD.IMAGE   ];
            
            var _sprite_texture = sprite_get_texture( _sprite, _image );
            if ( _sprite_texture != _previous_texture )
            {
                _previous_texture = _sprite_texture;
                    
                var _vbuff_map = _texture_to_vbuff_map[? _sprite_texture ];
                if ( _vbuff_map == undefined )
                {
                    var _vbuff = vertex_create_buffer();
                    vertex_begin( _vbuff, global.__scribble_vertex_format );
                
                    _vbuff_map = ds_map_create();
                    _vbuff_map[? "vertex buffer" ] = _vbuff;
                    _vbuff_map[? "sprite"        ] = _sprite;
                    _vbuff_map[? "texture"       ] = _sprite_texture;
                    ds_list_add( _vbuff_list, _vbuff_map );
                    ds_list_mark_as_map( _vbuff_list, ds_list_size( _vbuff_list )-1 );
                    
                    _texture_to_vbuff_map[? _sprite_texture ] = _vbuff_map;
                }
                else
                {
                    var _vbuff = _vbuff_map[? "vertex buffer" ];
                }
            }
            
            var _uvs = sprite_get_uvs( _sprite, _image );
            var _glyph_l = _word_l  + _uvs[4] + sprite_get_xoffset( _sprite );
            var _glyph_t = _word_t  + _uvs[5] + sprite_get_yoffset( _sprite );
            var _glyph_r = _glyph_l + _uvs[6]*sprite_get_width(  _sprite );
            var _glyph_b = _glyph_t + _uvs[7]*sprite_get_height( _sprite );
                
            vertex_position( _vbuff, _glyph_l, _glyph_t ); vertex_texcoord( _vbuff, _uvs[0], _uvs[1] ); vertex_colour( _vbuff, c_white, 1 ); vertex_float4( _vbuff, _char_pc, _line_pc, 0, 0 ); vertex_float3( _vbuff, _wave, _shake, _rainbow );
            vertex_position( _vbuff, _glyph_l, _glyph_b ); vertex_texcoord( _vbuff, _uvs[0], _uvs[3] ); vertex_colour( _vbuff, c_white, 1 ); vertex_float4( _vbuff, _char_pc, _line_pc, 0, 0 ); vertex_float3( _vbuff, _wave, _shake, _rainbow );
            vertex_position( _vbuff, _glyph_r, _glyph_b ); vertex_texcoord( _vbuff, _uvs[2], _uvs[3] ); vertex_colour( _vbuff, c_white, 1 ); vertex_float4( _vbuff, _char_pc, _line_pc, 0, 0 ); vertex_float3( _vbuff, _wave, _shake, _rainbow );
            vertex_position( _vbuff, _glyph_r, _glyph_b ); vertex_texcoord( _vbuff, _uvs[2], _uvs[3] ); vertex_colour( _vbuff, c_white, 1 ); vertex_float4( _vbuff, _char_pc, _line_pc, 0, 0 ); vertex_float3( _vbuff, _wave, _shake, _rainbow );
            vertex_position( _vbuff, _glyph_r, _glyph_t ); vertex_texcoord( _vbuff, _uvs[2], _uvs[1] ); vertex_colour( _vbuff, c_white, 1 ); vertex_float4( _vbuff, _char_pc, _line_pc, 0, 0 ); vertex_float3( _vbuff, _wave, _shake, _rainbow );
            vertex_position( _vbuff, _glyph_l, _glyph_t ); vertex_texcoord( _vbuff, _uvs[0], _uvs[1] ); vertex_colour( _vbuff, c_white, 1 ); vertex_float4( _vbuff, _char_pc, _line_pc, 0, 0 ); vertex_float3( _vbuff, _wave, _shake, _rainbow );
            
            ++_text_char;
            #endregion
        }
        else
        {
            #region Check the font and texture to see if we need a new vertex buffer
            var _font = _word_array[ __E_SCRIBBLE_WORD.FONT ];
            
            if ( _font != _previous_font )
            {
                _previous_font = _font;
                
                var _font_glyphs_map = global.__scribble_glyphs_map[? _font ];
                var _font_data       = global.__scribble_font_data[?  _font ];
                var _font_sprite     = _font_data[ __E_SCRIBBLE_FONT.SPRITE ];
                var _font_texture    = sprite_get_texture( _font_sprite, 0 );     
                
                if ( _font_texture != _previous_texture )
                {
                    _previous_texture = _font_texture;
                    
                    var _vbuff_map = _texture_to_vbuff_map[? _font_texture ];
                    if ( _vbuff_map == undefined )
                    {
                        var _vbuff = vertex_create_buffer();
                        vertex_begin( _vbuff, global.__scribble_vertex_format );
                
                        _vbuff_map = ds_map_create();
                        _vbuff_map[? "vertex buffer" ] = _vbuff;
                        _vbuff_map[? "sprite"        ] = _font_sprite;
                        _vbuff_map[? "texture"       ] = _font_texture;
                        ds_list_add( _vbuff_list, _vbuff_map );
                        ds_list_mark_as_map( _vbuff_list, ds_list_size( _vbuff_list )-1 );
                
                        _texture_to_vbuff_map[? _font_texture ] = _vbuff_map;
                    }
                    else
                    {
                        var _vbuff = _vbuff_map[? "vertex buffer" ];
                    }
                }
            }
            #endregion
            
            #region Add vertex data for each character in the string
            var _colour  = _word_array[ __E_SCRIBBLE_WORD.COLOUR  ];
            var _rainbow = _word_array[ __E_SCRIBBLE_WORD.RAINBOW ];
            var _shake   = _word_array[ __E_SCRIBBLE_WORD.SHAKE   ];
            var _wave    = _word_array[ __E_SCRIBBLE_WORD.WAVE    ];
            
            var _str = _word_array[ __E_SCRIBBLE_WORD.STRING ];
            var _string_size = string_length( _str );
            
            var _char_l = _word_l;
            var _char_t = _word_t;
            var _char_index = 1;
            repeat( _string_size )
            {
                var _array = _font_glyphs_map[? string_char_at( _str, _char_index ) ];
                if ( _array == undefined ) continue;
                
                var _glyph_w   = _array[ __E_SCRIBBLE_GLYPH.W   ];
                var _glyph_h   = _array[ __E_SCRIBBLE_GLYPH.H   ];
                var _glyph_u0  = _array[ __E_SCRIBBLE_GLYPH.U0  ];
                var _glyph_v0  = _array[ __E_SCRIBBLE_GLYPH.V0  ];
                var _glyph_u1  = _array[ __E_SCRIBBLE_GLYPH.U1  ];
                var _glyph_v1  = _array[ __E_SCRIBBLE_GLYPH.V1  ];
                var _glyph_dx  = _array[ __E_SCRIBBLE_GLYPH.DX  ];
                var _glyph_dy  = _array[ __E_SCRIBBLE_GLYPH.DY  ];
                var _glyph_shf = _array[ __E_SCRIBBLE_GLYPH.SHF ];
                
                var _glyph_l = _char_l + _glyph_dx;
                var _glyph_t = _char_t + _glyph_dy;
                var _glyph_r = _glyph_l + _glyph_w;
                var _glyph_b = _glyph_t + _glyph_h;
                
                var _char_pc = _text_char / _max_char;
                
                vertex_position( _vbuff, _glyph_l, _glyph_t ); vertex_texcoord( _vbuff, _glyph_u0, _glyph_v0 ); vertex_colour( _vbuff, _colour, 1 ); vertex_float4( _vbuff, _char_pc, _line_pc, 0, 0 ); vertex_float3( _vbuff, _wave, _shake, _rainbow );
                vertex_position( _vbuff, _glyph_l, _glyph_b ); vertex_texcoord( _vbuff, _glyph_u0, _glyph_v1 ); vertex_colour( _vbuff, _colour, 1 ); vertex_float4( _vbuff, _char_pc, _line_pc, 0, 0 ); vertex_float3( _vbuff, _wave, _shake, _rainbow );
                vertex_position( _vbuff, _glyph_r, _glyph_b ); vertex_texcoord( _vbuff, _glyph_u1, _glyph_v1 ); vertex_colour( _vbuff, _colour, 1 ); vertex_float4( _vbuff, _char_pc, _line_pc, 0, 0 ); vertex_float3( _vbuff, _wave, _shake, _rainbow );
                vertex_position( _vbuff, _glyph_r, _glyph_b ); vertex_texcoord( _vbuff, _glyph_u1, _glyph_v1 ); vertex_colour( _vbuff, _colour, 1 ); vertex_float4( _vbuff, _char_pc, _line_pc, 0, 0 ); vertex_float3( _vbuff, _wave, _shake, _rainbow );
                vertex_position( _vbuff, _glyph_r, _glyph_t ); vertex_texcoord( _vbuff, _glyph_u1, _glyph_v0 ); vertex_colour( _vbuff, _colour, 1 ); vertex_float4( _vbuff, _char_pc, _line_pc, 0, 0 ); vertex_float3( _vbuff, _wave, _shake, _rainbow );
                vertex_position( _vbuff, _glyph_l, _glyph_t ); vertex_texcoord( _vbuff, _glyph_u0, _glyph_v0 ); vertex_colour( _vbuff, _colour, 1 ); vertex_float4( _vbuff, _char_pc, _line_pc, 0, 0 ); vertex_float3( _vbuff, _wave, _shake, _rainbow );
                
                _char_l += _glyph_shf;
                ++_text_char;
                ++_char_index;
            }
            #endregion
        }
        
        ++_word;
    }
    
    ++_line;
}

//Finish off and freeze all the vertex buffers we created
var _vbuff_count = ds_list_size( _vbuff_list );
for( var _i = 0; _i < _vbuff_count; _i++ )
{
    var _vbuff_map = _vbuff_list[| _i ];
    var _vbuff = _vbuff_map[? "vertex buffer" ];
    vertex_end( _vbuff );
    vertex_freeze( _vbuff );
}

ds_map_destroy( _texture_to_vbuff_map );

#endregion



show_debug_message( "scribble_create() took " + string( (get_timer() - _timer)/1000 ) + "ms" );

return _json;