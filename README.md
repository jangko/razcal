# razcal

a cross platfrom desktop app framework written in Nim

---

### A bit history

If you come here, you should already know something about [electron](https://electron.atom.io/), a big desktop app framework written in C++. Perhaps you also know [CEF](https://bitbucket.org/chromiumembedded/cef), electron minus node.js.

Well, I used them both in the past, and some of my project still depend on earlier version of CEF, but they grow up immensely, adding much feature I don't need at all. Building the binary myself already a nightmare, removing unneeded features is worse.

Then I stumbled upon [Layx](https://github.com/layxlang/layx), a layout language written in javascript. Then I thought, hey, why not we have something like electron/CEF, but lightweight and hackable. And of course, don't use xml-like whatsoever for the layout, we already have too much xml-like language to describe GUI.

That is how razcal idea was born, written in Nim, using Layx inspired layout language, scripted by [moonscript](https://moonscript.org/) on top of [Lua](https://www.lua.org/) vm. Currently using [kiwi](https://github.com/yglukhov/kiwi) as it's constraint solver algorithm.


### roadmap

right now, razcal pretty much still an embryo, the parser, constraint solver engine, and lua binding already found it's way to communicate to each other, but many features of layout language still not implemented yet, backend renderer not available, test suite not available, documentation none, tutorial none.

* parser
  *  parse style section
  *  parse prop section
* semantic pass
  *  class instantiation
  *  applying prop and style to view
* lua binding
  * fix cfunction argument validation
  * reimplement metatable for userdata
  * add error reporting mechanism without using lua_error
* renderer
  * bring up crude renderer to design backend api
* test suite
  * robust test suite for both Nim and Lua side
  * automated build system + test