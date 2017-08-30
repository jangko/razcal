import strutils, idents, os, tables, utils

type
  FileInfo* = object
    fullPath: string           # This is a canonical full filesystem path
    projPath*: string          # This is relative to the project's root
    shortName*: string         # short name of the module
                               
  Context* = ref object
    identCache: IdentCache
    fileInfos: seq[FileInfo]
    filenameToIndex: Table[string, int32]
    
  LineInfo* = object
    line*, col*: int16
    fileIndex*: int32   
  
  SourceError* = object of Exception
    line*, column*: int
    lineContent*: string
    
  MsgKind* = enum
    errInvalidIndentation
    errExprExpected
    errIdentExpected    
    errTokenExpected
    
const
  InvalidFileIDX* = int32(-1)   
  
#const
  #MsgKindToStr*: array[MsgKind, string] = [
  
  
proc newContext*(): Context =
  new(result)
  result.identCache = newIdentCache()
  result.fileInfos = @[]
  result.filenameToIndex = initTable[string, int32]()
  
#proc msgKindToString*(kind: TMsgKind): string =
  # later versions may provide translated error messages
  #result = MsgKindToStr[kind]

#proc getMessageStr(msg: TMsgKind, arg: string): string =
  #result = msgKindToString(msg) % [arg]
#[  
proc fileInfoIdx*(filename: string; isKnownFile: var bool): int32 =
  var
    canon: string
    pseudoPath = false

  try:
    canon = canonicalizePath(filename)
    shallow(canon)
  except:
    canon = filename
    # The compiler uses "filenames" such as `command line` or `stdin`
    # This flag indicates that we are working with such a path here
    pseudoPath = true

  if filenameToIndexTbl.hasKey(canon):
    result = filenameToIndexTbl[canon]
  else:
    isKnownFile = false
    result = fileInfos.len.int32
    fileInfos.add(newFileInfo(canon, if pseudoPath: filename
                                     else: canon.shortenDir))
    filenameToIndexTbl[canon] = result
]#