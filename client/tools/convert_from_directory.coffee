#!/usr/bin/env coffee

# IMPORTS 
_ = require("underscore")
escodegen = require("escodegen")
esprima = require("esprima")
fs = require("fs.extra")
mime = require("mime")
path = require("path")
util = require("util")


# CONSTANTS
OUTPUT_VERSION = 0.1

# 2-space indent 
CODE_GENERATION_OPTIONS =
  indent: "  "


# FUNCTIONS
toJson = (obj) -> JSON.stringify(obj, null, 2)

# functionSerializer is a function of (arguments, body) 
parsedToObj = (parsed, functionSerializer) -> 
  switch parsed.type
    when "Literal"
      return parsed.value
    when "ObjectExpression"
      obj = {}
      for property in parsed.properties
        propertyName = property.key.name || property.key.value
        obj[propertyName] = parsedToObj(property.value, functionSerializer)
      return obj
    when "FunctionExpression" 
      # Don't include the upper-level BlockStatement
      args = (param.name for param in parsed.params)
      body = (escodegen.generate(body, CODE_GENERATION_OPTIONS) for body in parsed.body.body).join("\n")
      return functionSerializer(args, body)
    else
      util.error("How do I handle parsed type #{parsed.type}?")
      process.exit(2)

createDataUri = (filename) ->
  buffer = fs.readFileSync(filename)
  mimeType = mime.lookup(filename)
  return "data:#{mimeType};base64,#{buffer.toString('base64')}"

# Changes layout in-place
correctActions = (actions, processes, layoutNode) ->
  if "action" of layoutNode
    if layoutNode.action of actions 
      # leave as is 
      if "children" of layoutNode
        throw new Error("Action '#{layoutNode.action}' cannot have children") 
    else if layoutNode.action of processes
      # change from "action: 'blah'"" to "process: 'blah'"
      layoutNode.process = layoutNode.action
      delete layoutNode.action
    else
      throw new Error("Action '#{layoutNode.action}' is not an action or a process") 

  if layoutNode.children
    for child in layoutNode.children
      correctActions(actions, processes, child)

convertServicesToLayers = (services) ->
  layers = []

  # First come the canvas layers
  for layer in services.graphics?.options?.layers
    layers.push 
      name: layer
      type: "canvas"

  # Next the HTML
  if services.html
    layers.push
      name: "html"
      type: "html"

  return layers


# MAIN
if process.argv.length < 4
  util.error("Usage: coffee convert_from_directory.coffee <input_dir> <output_file>")
  process.exit(1)

inputDir = process.argv[2]
outputFile = process.argv[3]

# This object will be written out as JSON at the end 
outputObj = 
  name: path.basename(inputDir)
  fileVersion: OUTPUT_VERSION
  model: {}
  services: {}
  layout: {}
  actions: {}
  processes: {}
  tools: {}
  assets: {}

# Actions are in a JS file that needs to be parsed
parsedActions = esprima.parse(fs.readFileSync(path.join(inputDir, "actions.js"), { encoding: "utf8" }))
# Remove references to "this"
actionsJson = parsedToObj(parsedActions.body[0].expression, (args, body) -> body.replace(/this\./g, ""))
# Split between actions and processes
for name, value of actionsJson 
  if "update" of value 
    outputObj.actions[name] = value
  else
    outputObj.processes[name] = value

# Read layout.json
layoutJson = fs.readFileSync(path.join(inputDir, "layout.json"), { encoding: "utf8" })
# Rename "graphics" to "canvas"
layoutJson = layoutJson.replace(/services\.graphics/g, "services.canvas")
# Copy over layout JSON
outputObj.layout = JSON.parse(layoutJson)
# Correct between actions and processes
correctActions(outputObj.actions, outputObj.processes, outputObj.layout)

# Copy over model JSON
outputObj.model = JSON.parse(fs.readFileSync(path.join(inputDir, "model.json"), { encoding: "utf8" }))

# Create layers config 
parsedServices = JSON.parse(fs.readFileSync(path.join(inputDir, "services.json"), { encoding: "utf8" }))
outputObj.services = 
  layers: convertServicesToLayers(parsedServices)

# Tools are a JS file that needs to be parsed
parsedTools = esprima.parse(fs.readFileSync(path.join(inputDir, "tools.js"), { encoding: "utf8" }))
# Replace "this" references with tools. \b matches the word boundary
outputObj.tools = parsedToObj parsedTools.body[0].expression, (args, body) -> 
  {
    args: args
    body: body.replace(/this\.log/, "log").replace(/this\b/g, "tools") # Rename "this.log" -> "log" and "this.toto" to "tools.toto"
  }

# Create data-URI encoded versions of all assets
assetMap = JSON.parse(fs.readFileSync(path.join(inputDir, "assets.json"), { encoding: "utf8" }))
for name, filename of assetMap
  outputObj.assets[name] = createDataUri(path.join(inputDir, filename))

fs.writeFileSync(outputFile, toJson(outputObj))
