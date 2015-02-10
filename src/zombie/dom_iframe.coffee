# Support for iframes.


createHistory = require("./history")
DOM           = require("./dom")


# Support for iframes that load content when you set the src attribute.
frameInit = DOM.HTMLFrameElement._init
DOM.HTMLFrameElement._init = ->
  frameInit.call(this)
  @removeEventListener("DOMNodeInsertedIntoDocument", @_initInsertListener)

  frame = this

  parentWindow = frame.ownerDocument.parentWindow
  contentWindow = null

  Object.defineProperties frame,
    contentWindow:
      get: ->
        return contentWindow || create()
    contentDocument:
      get: ->
        return (contentWindow || create()).document

  # URL created on the fly, or when src attribute set
  create = (url)->
    # Change the focus from window to active.
    focus = (active)->
      contentWindow = active
    # Need to bypass JSDOM's window/document creation and use ours
    open = createHistory(parentWindow.browser, focus)
    contentWindow = open(name: frame.name, parent: parentWindow, url: url, referrer: parentWindow.location.href)
    return contentWindow



# This is also necessary to prevent JSDOM from messing with window/document
DOM.HTMLFrameElement.prototype.setAttribute = (name, value)->
  DOM.HTMLElement.prototype.setAttribute.call(this, name, value)

DOM.HTMLFrameElement.prototype._attrModified = (name, value, oldValue)->
  DOM.HTMLElement.prototype._attrModified.call(this, name, value, oldValue)
  if name == "name"
    @ownerDocument.parentWindow.__defineGetter__ value, =>
      return @contentWindow
  else if name == "src" && value
    url = DOM.resourceLoader.resolve(@ownerDocument, value)
    # Don't load IFrame twice
    if @contentWindow.location.href == url
      return
    # Point IFrame at new location and wait for it to load
    @contentWindow.location = url
    onload = =>
      @contentWindow.removeEventListener("load", onload)
      onload = @ownerDocument.createEvent("HTMLEvents")
      onload.initEvent("load", true, false)
      @dispatchEvent(onload)
    @contentWindow.addEventListener("load", onload)
