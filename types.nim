type
  # information about a file(raz, lua, etc)
  RazFileInfo* = object
    fullPath*: string           # This is a canonical full filesystem path
    projPath*: string          # This is relative to the project's root
    shortName*: string         # short name of the module
    fileName*: string          # name.ext

  # used in Node and Symbol
  RazLineInfo* = object
    line*, col*: int16
    fileIndex*: int32          # index into FileInfo list

  # Lexer and Parser throw this exception
  SourceError* = ref object of Exception
    line*, column*: int
    lineContent*: string       # full source line content
    fileIndex*: int32          # index into FileInfo list

  # Semcheck and friends throw this exception
  # useful for debugging purpose
  # A stable app should never throw this exception
  InternalError* = ref object of Exception
    line*: int                 # Nim source line
    fileName*: string          # Nim source file name

  OtherError* = ref object of Exception
