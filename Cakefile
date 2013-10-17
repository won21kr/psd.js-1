fs            = require 'fs'
{exec, spawn} = require 'child_process'
util          = require 'util'
{jsmin}       = require 'jsmin'

targetName    = "psd"

###
CoffeeScript Options
###
strictMode    = false
csSrcDir      = "src"
csTargetDir   = "lib"

depsDir       = "deps"

targetCoffee  = "#{csSrcDir}/build"

targetCoreJS      = "#{csTargetDir}/#{targetName}.js"
targetCoreMinJS   = "#{csTargetDir}/#{targetName}.min.js"
coffeeCoreOpts    = "-j #{targetName}.js -o #{csTargetDir} -c #{targetCoffee}.coffee"

# All source files listed in include order
coffeeFiles   = [
  "psdassert"
  
  "psd"
  "psdcolor"
  "psddescriptor"
  "psdfile"
  "psdheader"
  "psdimage"
  "psdchannelimage"
  "psdlayer"
  "psdlayermask"

  "layerdata/blackwhite"
  "layerdata/brightnesscontrast"
  "layerdata/colorbalance"
  "layerdata/curves"
  "layerdata/exposure"
  "layerdata/gradient"
  "layerdata/huesaturation"
  "layerdata/invert"
  "layerdata/layereffect"
  "layerdata/levels"
  "layerdata/pattern"
  "layerdata/photofilter"
  "layerdata/posterize"
  "layerdata/selectivecolor"
  "layerdata/solidcolor"
  "layerdata/threshold"
  "layerdata/typetool"
  "layerdata/vibrance"

  "psdresource"
  "util"
  "log"
]

###
Event System
###
finishedCallback = {}
finished = (type) ->      
  finishedCallback[type]() if finishedCallback[type]?

finishListener = (type, cb) ->
  finishedCallback[type] = cb

###
Options
###
option '-f', '--file [FILE]', 'Test file to load (for debugging)'

###
Tasks
###
task 'debug', 'Run psd.js in debug mode with node-inspector', (opts) ->
  throw "Must specify a file with -f" if not opts.file

  debug = spawn 'coffee', ['--nodejs', '--debug-brk', opts.file]
  debug.stdout.on 'data', (data) -> console.log data

  insp = spawn 'node-inspector'
  insp.stdout.on 'data', (data) -> util.log data

  exec 'open http://127.0.0.1:8080/debug?port=5858'

task 'docs', 'Generates documentation for the coffee files', ->
  util.log 'Invoking docco on the CoffeeScript source files'
  
  files = coffeeFiles
  files[i] = "#{csSrcDir}/#{files[i]}.coffee" for i in [0...files.length]

  exec "./node_modules/docco/bin/docco #{files.join(' ')}", (err, stdout, stderr) ->
    util.log err if err
    util.log "Documentation built into docs/ folder."

task 'test', 'Run all unit tests', ->
  reporter = require('nodeunit').reporters.default
  process.chdir __dirname

  console.log "=> Running unit tests"
  reporter.run ['test/unit_tests'], null, ->

    {TargetPractice} = require './test/targetpractice'
    tp = new TargetPractice "psd.tp/**/*.json"

    console.log "\n=> Running TargetPractice"
    tp.runTests()
        
task 'watch', 'Automatically recompile the CoffeeScript files when updated', ->
  util.log "Watching for changes in #{csSrcDir}"
  
  for jsFile in coffeeFiles then do (jsFile) ->
    fs.watchFile "#{csSrcDir}/#{jsFile}.coffee", (curr, prev) ->
      if +curr.mtime isnt +prev.mtime
        util.log "#{csSrcDir}/#{jsFile}.coffee updated"
        invoke 'build'
        
task 'build', 'Compile and minify all CoffeeScript source files', ->
  finishListener 'js', -> invoke 'minify'
  invoke 'compile'

task 'compile', 'Compile all CoffeeScript source files', (opts) ->
  util.log "Building #{targetCoreJS}"
  contents = []
  remaining = coffeeFiles.length

  util.log "Appending #{coffeeFiles.length} files to #{targetCoffee}.coffee"
  
  for file, index in coffeeFiles then do (file, index) ->
    fs.readFile "#{csSrcDir}/#{file}.coffee", "utf8", (err, fileContents) ->
      util.log err if err
      
      contents[index] = fileContents
      util.log "[#{index + 1}] #{file}.coffee"
      process() if --remaining is 0
      
  process = ->
    contents.unshift "###\nEND DEPENDENCIES\n###\n\n"
    deps = fs.readdirSync depsDir
    for dep in deps
      util.log "Adding dependency #{dep}"
      contents.unshift "`" + fs.readFileSync("#{depsDir}/#{dep}", "utf8") + "`\n\n"

    contents.unshift fs.readFileSync("#{csSrcDir}/license.coffee") + "\n\n"
    contents.unshift "\"use strict\"" if strictMode
    core = contents.join("\n\n")

    fs.writeFile "#{targetCoffee}.coffee", core, "utf8", (err) ->
      util.log err if err
      
      exec "./node_modules/.bin/coffee #{coffeeCoreOpts}", (err, stdout, stderr) ->
        util.log err if err
        util.log "Compiled #{targetCoreJS}"
        fs.unlink "#{targetCoffee}.coffee"

        finished('js')
        
task 'minify', 'Minify the CoffeeScript files', ->
  util.log "Minifying #{targetCoreJS}"
  fs.readFile targetCoreJS, "utf8", (err, contents) ->
    fs.writeFile targetCoreMinJS, jsmin(contents), "utf8", (err) ->
      util.log err if err