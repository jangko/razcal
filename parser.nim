import lexer, lexbase, idents, streams, os

type
  Parser* = object
    currInd: int
    firstTok: bool
    hasProgress: bool
    lex*: Lexer
    tok*: Token

proc getTok(p: var Parser) =
  p.lex.getToken(p.tok)
  p.hasProgress = true

proc initParser*(inputStream: Stream, identCache: IdentCache): Parser =
  result.tok = initToken()
  result.lex = initLexer(inputStream, identCache)
  result.getTok() # read the first token
  result.firstTok = true

proc close*(p: var Parser) =
  p.lex.close()
  
proc main() =
  var input = newFileStream(paramStr(1))
  var identCache = newIdentCache()
  var p = initParser(input, identCache)

main()

