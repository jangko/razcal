const NamedColors* = {
  "IndianRed": 0xCD5C5C'u32,
  "LightCoral": 0xF08080'u32,
  "Salmon": 0xFA8072'u32,
  "DarkSalmon": 0xE9967A'u32,
  "LightSalmon": 0xFFA07A'u32,
  "Crimson": 0xDC143C'u32,
  "Red": 0xFF0000'u32,
  "FireBrick": 0xB22222'u32,
  "DarkRed": 0x8B0000'u32,
  "Pink": 0xFFC0CB'u32,
  "LightPink": 0xFFB6C1'u32,
  "HotPink": 0xFF69B4'u32,
  "DeepPink": 0xFF1493'u32,
  "MediumVioletRed": 0xC71585'u32,
  "PaleVioletRed": 0xDB7093'u32,
  "LightSalmon": 0xFFA07A'u32,
  "Coral": 0xFF7F50'u32,
  "Tomato": 0xFF6347'u32,
  "OrangeRed": 0xFF4500'u32,
  "DarkOrange": 0xFF8C00'u32,
  "Orange": 0xFFA500'u32,
  "Gold": 0xFFD700'u32,
  "Yellow": 0xFFFF00'u32,
  "LightYellow": 0xFFFFE0'u32,
  "LemonChiffon": 0xFFFACD'u32,
  "LightGoldenrodYellow": 0xFAFAD2'u32,
  "PapayaWhip": 0xFFEFD5'u32,
  "Moccasin": 0xFFE4B5'u32,
  "PeachPuff": 0xFFDAB9'u32,
  "PaleGoldenrod": 0xEEE8AA'u32,
  "Khaki": 0xF0E68C'u32,
  "DarkKhaki": 0xBDB76B'u32,
  "Lavender": 0xE6E6FA'u32,
  "Thistle": 0xD8BFD8'u32,
  "Plum": 0xDDA0DD'u32,
  "Violet": 0xEE82EE'u32,
  "Orchid": 0xDA70D6'u32,
  "Fuchsia": 0xFF00FF'u32,
  "Magenta": 0xFF00FF'u32,
  "MediumOrchid": 0xBA55D3'u32,
  "MediumPurple": 0x9370DB'u32,
  "Amethyst": 0x9966CC'u32,
  "BlueViolet": 0x8A2BE2'u32,
  "DarkViolet": 0x9400D3'u32,
  "DarkOrchid": 0x9932CC'u32,
  "DarkMagenta": 0x8B008B'u32,
  "Purple": 0x800080'u32,
  "Indigo": 0x4B0082'u32,
  "SlateBlue": 0x6A5ACD'u32,
  "DarkSlateBlue": 0x483D8B'u32,
  "MediumSlateBlue": 0x7B68EE'u32,
  "GreenYellow": 0xADFF2F'u32,
  "Chartreuse": 0x7FFF00'u32,
  "LawnGreen": 0x7CFC00'u32,
  "Lime": 0x00FF00'u32,
  "LimeGreen": 0x32CD32'u32,
  "PaleGreen": 0x98FB98'u32,
  "LightGreen": 0x90EE90'u32,
  "MediumSpringGreen": 0x00FA9A'u32,
  "SpringGreen": 0x00FF7F'u32,
  "MediumSeaGreen": 0x3CB371'u32,
  "SeaGreen": 0x2E8B57'u32,
  "ForestGreen": 0x228B22'u32,
  "Green": 0x008000'u32,
  "DarkGreen": 0x006400'u32,
  "YellowGreen": 0x9ACD32'u32,
  "OliveDrab": 0x6B8E23'u32,
  "Olive": 0x808000'u32,
  "DarkOliveGreen": 0x556B2F'u32,
  "MediumAquamarine": 0x66CDAA'u32,
  "DarkSeaGreen": 0x8FBC8F'u32,
  "LightSeaGreen": 0x20B2AA'u32,
  "DarkCyan": 0x008B8B'u32,
  "Teal": 0x008080'u32,
  "Aqua": 0x00FFFF'u32,
  "Cyan": 0x00FFFF'u32,
  "LightCyan": 0xE0FFFF'u32,
  "PaleTurquoise": 0xAFEEEE'u32,
  "Aquamarine": 0x7FFFD4'u32,
  "Turquoise": 0x40E0D0'u32,
  "MediumTurquoise": 0x48D1CC'u32,
  "DarkTurquoise": 0x00CED1'u32,
  "CadetBlue": 0x5F9EA0'u32,
  "SteelBlue": 0x4682B4'u32,
  "LightSteelBlue": 0xB0C4DE'u32,
  "PowderBlue": 0xB0E0E6'u32,
  "LightBlue": 0xADD8E6'u32,
  "SkyBlue": 0x87CEEB'u32,
  "LightSkyBlue": 0x87CEFA'u32,
  "DeepSkyBlue": 0x00BFFF'u32,
  "DodgerBlue": 0x1E90FF'u32,
  "CornflowerBlue": 0x6495ED'u32,
  "MediumSlateBlue": 0x7B68EE'u32,
  "RoyalBlue": 0x4169E1'u32,
  "Blue": 0x0000FF'u32,
  "MediumBlue": 0x0000CD'u32,
  "DarkBlue": 0x00008B'u32,
  "Navy": 0x000080'u32,
  "MidnightBlue": 0x191970'u32,
  "Cornsilk": 0xFFF8DC'u32,
  "BlanchedAlmond": 0xFFEBCD'u32,
  "Bisque": 0xFFE4C4'u32,
  "NavajoWhite": 0xFFDEAD'u32,
  "Wheat": 0xF5DEB3'u32,
  "BurlyWood": 0xDEB887'u32,
  "Tan": 0xD2B48C'u32,
  "RosyBrown": 0xBC8F8F'u32,
  "SandyBrown": 0xF4A460'u32,
  "Goldenrod": 0xDAA520'u32,
  "DarkGoldenrod": 0xB8860B'u32,
  "Peru": 0xCD853F'u32,
  "Chocolate": 0xD2691E'u32,
  "SaddleBrown": 0x8B4513'u32,
  "Sienna": 0xA0522D'u32,
  "Brown": 0xA52A2A'u32,
  "Maroon": 0x800000'u32,
  "White": 0xFFFFFF'u32,
  "Snow": 0xFFFAFA'u32,
  "Honeydew": 0xF0FFF0'u32,
  "MintCream": 0xF5FFFA'u32,
  "Azure": 0xF0FFFF'u32,
  "AliceBlue": 0xF0F8FF'u32,
  "GhostWhite": 0xF8F8FF'u32,
  "WhiteSmoke": 0xF5F5F5'u32,
  "Seashell": 0xFFF5EE'u32,
  "Beige": 0xF5F5DC'u32,
  "OldLace": 0xFDF5E6'u32,
  "FloralWhite": 0xFFFAF0'u32,
  "Ivory": 0xFFFFF0'u32,
  "AntiqueWhite": 0xFAEBD7'u32,
  "Linen": 0xFAF0E6'u32,
  "LavenderBlush": 0xFFF0F5'u32,
  "MistyRose": 0xFFE4E1'u32,
  "Gainsboro": 0xDCDCDC'u32,
  "LightGrey": 0xD3D3D3'u32,
  "Silver": 0xC0C0C0'u32,
  "DarkGray": 0xA9A9A9'u32,
  "Gray": 0x808080'u32,
  "DimGray": 0x696969'u32,
  "LightSlateGray": 0x778899'u32,
  "SlateGray": 0x708090'u32,
  "DarkSlateGray": 0x2F4F4F'u32,
  "Black": 0x000000'u32
  }
