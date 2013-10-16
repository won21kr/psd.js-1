# NodeJS or browser?
if exports?
  Root = exports
  fs = require 'fs'
else
  Root = window

# Create our class and add to global scope
Root.PSD = class PSD
  # Version number
  @VERSION = "0.4.6"

  # Enable/disable debugging console logs
  @DEBUG = false

  # Loads a PSD from a file. If we're in node, then this loads the
  # file from the filesystem. If we're in the browser, then this assumes
  # it has been passed a File object (either from a file input element,
  # or from HTML5 drag & drop).
  @fromFile: (file, cb = ->) ->
    if exports?
      # We're in node. Load via fs module.
      # Callback function isn't needed.
      data = fs.readFileSync file
      new PSD data
    else
      # We're in the browser. Assume we have a File object.
      reader = new FileReader()
      reader.onload = (f) ->
        # In order to convert the file data to a useful format, we need
        # to conver the buffer into a byte array.
        bytes = new Uint8Array(f.target.result)

        psd = new PSD(bytes)
        cb(psd)

      reader.readAsArrayBuffer(file)

  # Load a PSD from a URL via ajax
  @fromURL: (url, cb = ->) ->
    xhr = new XMLHttpRequest
    xhr.open "GET", url, true
    xhr.responseType = "arraybuffer"
    xhr.onload = ->
      data = new Uint8Array(xhr.response or xhr.mozResponseArrayBuffer)
      psd = new PSD(data)
      cb(psd)

    xhr.send null

  options:
    layerImages: false # Should we parse layer image data?
    onlyVisibleLayers: false # Should we skip invisible layer image parsing?
  
  constructor: (data) ->
    # Store the main reference to our PSD file
    @file = new PSDFile data

    @header = null
    @resources = null
    @layerMask = null
    @layers = null
    @images = null
    @image = null

  setOptions: (options) ->
    @options[key] = val for own key, val of options

  # Attempt to parse all sections of the PSD file
  parse: ->
    Log.debug "Beginning parsing"
    @startTime = (new Date()).getTime()

    # It's important to parse all of the file sections in the correct order,
    # which is used here.
    @parseHeader()
    @parseImageResources()
    @parseLayersMasks()
    @parseImageData()

    @endTime = (new Date()).getTime()
    Log.debug "Parsing finished in #{@endTime - @startTime}ms"

  # Parse the first section: the header.
  # This section cannot be skipped, since it contains important parsing information
  # for the rest of the PSD file (and is relatively small anyways).
  parseHeader: ->
    Log.debug "\n### Header ###"

    # Store a reference to the file header
    @header = new PSDHeader @file
    @header.parse()

    Log.debug @header

  parseImageResources: (skip = false) ->
    Log.debug "\n### Resources ###"

    # Every PSD file has a number of resources, so we simply store them in an
    # array for now. In the future, it might make more sense to store resources
    # in an object indexed by the resource ID.
    @resources = []

    # Find the size of the resources section
    n = @file.readInt()
    length = n

    if skip
      Log.debug "Skipped!"
      return @file.seek n

    start = @file.tell()

    # Continue parsing resources until we've reached the end of the section.
    while n > 0
      pos = @file.tell()

      resource = new PSDResource @file
      resource.parse()

      n -= @file.tell() - pos
      @resources.push resource

      Log.debug "Resource: ", resource

    # This shouldn't happen. If it does, then likely something is being parsed
    # incorrectly in one of the resources, or the file is corrupt.
    if n isnt 0
      Log.debug "Image resources overran expected size by #{-n} bytes"
      @file.seek start + length

  parseLayersMasks: (skip = false) ->
    @parseHeader() unless @header
    @parseImageResources(true) unless @resources

    Log.debug "\n### Layers & Masks ###"

    @layerMask = new PSDLayerMask @file, @header, @options
    @layers = @layerMask.layers

    if skip
      Log.debug "Skipped!"
      @layerMask.skip()
    else
      @layerMask.parse()

  parseImageData: ->
    @parseHeader() unless @header
    @parseImageResources(true) unless @resources
    @parseLayersMasks(true) unless @layerMask

    @image = new PSDImage @file, @header
    @image.parse()

  # Folder layers are denoted by a flag, isFolder. This marks the beginning
  # of the folder. The end of the folder is marked by the isHidden flag.
  getLayerStructure: ->
    @parseLayersMasks() unless @layerMask

    result = {layers: []}
    parseStack = []
    for layer in @layers
      if layer.isFolder
        parseStack.push result
        result = {visible: layer.visible, folder: true, name: layer.name, layers: []}
      else if layer.isHidden
        current = result
        result = parseStack.pop()
        result.layers.push current
      else
        result.layers.push layer

    result

  # Exports a flattened version to a file. For use in NodeJS.
  toFile: (filename, cb = ->) -> 
    @parseImageData() unless @image
    @image.toFile filename, cb

  toFileSync: (filename) ->
    @parseImageData() unless @image
    @image.toFileSync filename

  # Given a canvas element
  toCanvas: (canvas, width = null, height = null) ->
    @parseImageData() unless @image
    @image.toCanvas canvas, width, height

  toImage: ->
    @parseImageData() unless @image
    @image.toImage()

  # Extracts all parsed data from this PSD in a clean JSON
  # format excluding file and image data.
  toJSON: ->
    @parseLayersMasks() unless @layerMask

    sections = [
      'header'
      'layerMask'
    ]

    data = resources: []

    for resource in @resources
      data.resources.push resource.toJSON()

    for section in sections
      data[section] = @[section].toJSON()

    data
