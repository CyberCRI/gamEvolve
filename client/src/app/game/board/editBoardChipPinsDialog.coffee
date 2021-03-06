
angular.module('gamEvolve.game.board.editChipPinsDialog', [
  'ui.bootstrap'
])

.controller 'EditBoardChipPinsDialogCtrl', ($scope, liaison, currentGame, pins) ->
  # Source must start with 'memory' or 'services', then a dot, then some more text or indexing
  sourceIsSimple = (source) -> /^(memory|services)\.[\w.\[\]]+$/.test(source)

  # Drain must be a simple mapping of the pin
  drainIsSimple = (name, outValues) -> "pins.#{name}" in _.values(outValues)

  # Determine if pin destination is 'simple' or 'custom'
  determineLinkage = (name, direction, inValues, outValues) ->
    if direction in ['in', 'inout'] and not sourceIsSimple(inValues[name]) then return 'custom'
    if direction in ['out', 'inout'] and not drainIsSimple(name, outValues) then return 'custom'
    # The drain and source destinations must be equal
    if direction is 'inout' and outValues[inValues[name]] isnt "pins.#{name}" then return 'custom'
    return 'simple'

  # Only valid if determineLinkage() returns 'simple'
  getSimpleDestination = (name, direction, inValues, outValues) ->
    if direction in ['in', 'inout'] then return inValues[name]
    for destination, expression of outValues
      if expression is "pins.#{name}" then return destination
    throw new Error("Cannot find simple destination for pin '#{name}'")

  findPinReferences = (name, outValues) ->
    return ({ drain: drain, source: source } for drain, source of outValues when source.indexOf("pins.#{name}") != -1)

  convertPinsToModel = (pins) ->
    result =
      in: {}
      out: {}
    for pin in pins
      if pin.direction in ['in', 'inout']
        result.in[pin.name] = if pin.linkage is 'simple' then pin.simpleDestination else pin.customDestinations.in
      if pin.direction in ['out', 'inout']
        if pin.linkage is 'simple'
          result.out[pin.simpleDestination] = "pins.#{pin.name}"
        else
          for destination in pin.customDestinations.out
            result.out[destination.drain] = destination.source
    return result

  $scope.LINKAGES = ['simple', 'custom']
  $scope.DESTINATIONS = pins.enumeratePinDestinations()

  $scope.exchange = {}
  $scope.exchange.name = liaison.model.comment
  $scope.exchange.childName = if liaison.model.name? then JSON.stringify(liaison.model.name) else ""

  # Depending on if this is an processor, switch, or circuit, get the right kind of data
  # TODO: move this to calling controller?
  typeDef = null
  if 'processor' of liaison.model
    $scope.kind = 'Processor'
    $scope.type = liaison.model.processor
    typeDef = currentGame.version.processors[$scope.type] || currentGame.standardLibrary.processors[$scope.type]
  else if 'switch' of liaison.model
    $scope.kind = 'Switch'
    $scope.type = liaison.model.switch
    typeDef = currentGame.version.switches[$scope.type] || currentGame.standardLibrary.switches[$scope.type]
  else if 'circuit' of liaison.model
    $scope.kind = 'Circuit'
    $scope.type = liaison.model.circuit
    typeDef = currentGame.version.circuits[$scope.type] || currentGame.standardLibrary.circuits[$scope.type]
  else
    throw new Error('Model is not a processor, switch, or circuit')

  # TODO: refactor into function
  $scope.exchange.pins = []
  for pinName, pinDef of typeDef.pinDefs
    pin =
      name: pinName
      direction: pinDef?.direction ? 'in'
      default: pinDef?.default
      simpleDestination: ''
      customDestinations:
        in: ''
        out: []
    pin.linkage = determineLinkage(pinName, pin.direction, liaison.model.pins.in, liaison.model.pins.out)
    if pin.linkage == 'simple'
      pin.simpleDestination = getSimpleDestination(pinName, pin.direction, liaison.model.pins.in, liaison.model.pins.out)
    else
      pin.customDestinations.in = liaison.model.pins.in[pinName]
      pin.customDestinations.out = findPinReferences(pinName, liaison.model.pins.out)
    $scope.exchange.pins.push(pin)

  $scope.addCustomDestination = (pinName) ->
    pin = _.where($scope.exchange.pins, { name: pinName })[0]
    pin.customDestinations.out.push({ drain: '', source: '' })
  $scope.removeCustomDestination = (pinName, index) ->
    pin = _.where($scope.exchange.pins, { name: pinName })[0]
    pin.customDestinations.out.splice(index, 1)

  # Reply with the new data
  $scope.done = -> liaison.done
    comment: $scope.exchange.name
    name: if $scope.exchange.childName then JSON.parse($scope.exchange.childName) else null 
    pins: convertPinsToModel($scope.exchange.pins)
  $scope.cancel = -> liaison.cancel()
