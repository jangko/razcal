import hashes, strutils, keywords

type
  IDobj* = ref object of RootObj
    id*: int # unique id; use this for comparisons and not the pointers

  Ident* = ref object of IDobj
    s*: string
    next*: Ident             # for hash-table chaining
    h*: Hash                 # hash value of s

  IdentCache* = ref object
    buckets: array[0..4096 * 2 - 1, Ident]
    wordCounter: int
    idAnon*, emptyIdent*: Ident

template hash*(ident: Ident): Hash =
  hash(ident.id)

proc `$`*(self: Ident): string =
  result = if self.isNil: "nil" else: self.s

proc getIdent*(self: IdentCache; ident: string, h: Hash): Ident =
  let idx = h and high(self.buckets)
  result = self.buckets[idx]
  var last = Ident(nil)
  var id = 0
  while result != nil:
    if result.s == ident:
      if last != nil:
        # make access to last looked up identifier faster:
        last.next = result.next
        result.next = self.buckets[idx]
        self.buckets[idx] = result
      return
    last = result
    result = result.next

  new(result)
  result.h = h
  result.s = ident
  result.next = self.buckets[idx]
  self.buckets[idx] = result
  if id == 0:
    inc(self.wordCounter)
    result.id = -self.wordCounter
  else:
    result.id = id

proc getIdent*(self: IdentCache; ident: string): Ident {.inline.} =
  result = self.getIdent(ident, hash(ident))

proc newIdentCache*(): IdentCache =
  new(result)
  result.idAnon = result.getIdent":anonymous"
  result.wordCounter = 1
  result.emptyIdent = result.getIdent("")

  # initialize the keywords:
  for s in countup(succ(low(SpecialWords)), high(SpecialWords)):
    let idx = ord(s)
    result.getIdent(specialWords[idx-1], hash(specialWords[idx-1])).id = idx
