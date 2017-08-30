import os

proc canonicalizePath*(path: string): string =
  # on Windows, 'expandFilename' calls getFullPathName which doesn't do
  # case corrections, so we have to use this convoluted way of retrieving
  # the true filename
  when defined(windows):
    result = path.expandFilename
    for x in walkFiles(result):
      return x
  else:
    result = path.expandFilename
#[
proc shortenDir*(dir: string): string =
  ## returns the interesting part of a dir
  var prefix = gProjectPath & DirSep
  if startsWith(dir, prefix):
    return substr(dir, len(prefix))
  prefix = getPrefixDir() & DirSep
  if startsWith(dir, prefix):
    return substr(dir, len(prefix))
  result = dir
]#
proc removeTrailingDirSep*(path: string): string =
  if (len(path) > 0) and (path[len(path) - 1] == DirSep):
    result = substr(path, 0, len(path) - 2)
  else:
    result = path