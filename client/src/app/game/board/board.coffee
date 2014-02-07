# TODO Delete - The next two methods are now in currentGame service

# For accessing a chip within a board via it's path
# Takes the board object and the 'path' as an array
# Returns [parent, key] where parent is the parent chip and key is last one required to access the child
getBoardParentAndKey = (parent, pathParts) ->
  if pathParts.length is 0 then return [parent, null]
  if pathParts.length is 1 then return [parent, pathParts[0]]
  if pathParts[0] < parent.children.length then return getBoardParentAndKey(parent.children[pathParts[0]], _.rest(pathParts))
  throw new Error("Cannot find intermediate key '#{pathParts[0]}'")

getBoardChip = (parent, pathParts) ->
  if pathParts.length is 0 then return parent

  [foundParent, index] = getBoardParentAndKey(parent, pathParts)
  return foundParent.children[index]

enumerateModelKeys = (model, prefix = ['model'], keys = []) ->
  for name, value of model
    keys.push(GE.appendToArray(prefix, name).join('.'))
    if GE.isOnlyObject(value) then enumerateModelKeys(value, GE.appendToArray(prefix, name), keys)
  return keys

enumerateServiceKeys = (services,  keys = []) ->
  # TODO: dig down a bit into what values the services provide
  for name of services
    keys.push(['services', name].join('.'))
  return keys

enumeratePinDestinations = (gameVersion) ->
  destinations = enumerateModelKeys(gameVersion.model)
  enumerateServiceKeys(GE.services, destinations)
  return destinations



angular.module('gamEvolve.game.board', [
  'ui.bootstrap',
])

.directive 'boardTree', (currentGame, boardConverter) ->

    dnd =

      drag_check: (data) ->
        # No dropping in processors or emitters
        if data.r.attr('rel') in ['processor', 'emitter'] then return false

        # TODO: allow adding nodes before and after, not just inside
        result =
          after: false
          before: false
          inside: true
        return result

      drag_finish: (data) ->
        source = if 'processor-id' of data.o.attributes
            processor: data.o.attributes['processor-id'].nodeValue
            pins:
              in: {}
              out: {}
          else if 'switch-id' of data.o.attributes
            switch: data.o.attributes['switch-id'].nodeValue
            pins:
              in: {}
              out: {}
          else if 'emitter' of data.o.attributes
            emitter: {}
          else if 'splitter' of data.o.attributes
            splitter:
              from: ''
              bindTo: ''
              index: ''
          else
            throw new Error("Unknown element #{data.o} accepted for drag and drop")

        path = data.r.data('path')
        target = currentGame.getTreeNode(path)

        # If the target doesn't have children, it needs an empty list
        if not target.children? then target.children = []
        target.children.unshift source

    types =
      switch:
        icon:
          image: '/assets/images/switch.png'
      processor:
        valid_children: [] # Leaves in the tree
        icon:
          image: '/assets/images/processor.png'
      emitter:
        valid_children: [] # Leaves in the tree
        icon:
          image: '/assets/images/emitter.png'
      splitter:
        icon:
          image: '/assets/images/splitter.png'

    restrict: 'E'
    scope: {}
    controller: 'BoardCtrl'

    link: (scope, element) ->

      updateModel = ->
        treeJson = $.jstree._reference(element).get_json()[0]
        reverted = boardConverter.revert(treeJson)
        currentGame.version.board = reverted

      scope.updateTree = (board) ->
        $(element).jstree
          json_data:
            data: board
          dnd: dnd
          types:
            types: types
          core:
            html_titles: true
          plugins: ['themes', 'ui', 'json_data', 'dnd', 'types', 'wholerow', 'crrm']
        .bind "move_node.jstree", ->
          updateModel()

      $(element).on 'click', 'a[editChip]', (eventObject) ->
        clicked = $(eventObject.target)
        emitEditEvent = (path) ->
          scope.$emit 'editChipButtonClick', JSON.parse(path)
        if clicked.attr('editChip')
          emitEditEvent clicked.attr('editChip')
        else
          emitEditEvent $(clicked.parent()[0]).attr('editChip')

      $(element).on 'click', 'a[removeChip]', (eventObject) ->
        clicked = $(eventObject.target)
        emitRemoveEvent = (path) ->
          scope.$emit 'removeChipButtonClick', JSON.parse(path)
        if clicked.attr('removeChip')
          emitRemoveEvent clicked.attr('removeChip')
        else
          emitRemoveEvent $(clicked.parent()[0]).attr('removeChip')


.controller 'BoardCtrl', ($scope, $dialog, boardConverter, currentGame, gameHistory, gameTime) ->

    $scope.game = currentGame

    # When the board changes, update in scope
    updateBoard = ->
      if currentGame.version?.board
        $scope.updateTree( boardConverter.convert(currentGame.version.board) )
    $scope.$watch('game.version.board', updateBoard, true)

    # Update from gameHistory
    onUpdateGameHistory = ->
      if not gameHistory.data.frames[gameTime.currentFrameNumber]? then return
      newMemory = gameHistory.data.frames[gameTime.currentFrameNumber].memory
      if not _.isEqual($scope.memory, newMemory)
        $scope.memory = newMemory
    $scope.$watch('gameHistoryMeta', onUpdateGameHistory, true)

    showDialog = (templateUrl, controller, model, onDone) ->
      dialog = $dialog.dialog
        backdrop: true
        dialogFade: true
        backdropFade: true
        backdropClick: false
        templateUrl: templateUrl
        controller: controller
        resolve:
        # This object will be provided to the dialog as a dependency, and serves to communicate between the two
          liaison: ->
            {
            model: GE.cloneData(model)
            done: (newModel) ->
              onDone(newModel)
              dialog.close()
            cancel: ->
              dialog.close()
            }
      dialog.open()

    $scope.remove = (path) ->
      [parent, index] = getBoardParentAndKey(currentGame.version.board, path)
      parent.children.splice(index, 1) # Remove that child

    $scope.edit = (path) ->
      chip = getBoardChip(currentGame.version.board, path)
      # Determine type of chip
      if 'processor' of chip
        showDialog 'game/board/editBoardProcessor.tpl.html', 'EditBoardProcessorDialogCtrl', chip, (model) ->
          _.extend(chip, model)
      else if 'switch' of chip
        showDialog 'game/board/editBoardProcessor.tpl.html', 'EditBoardProcessorDialogCtrl', chip, (model) ->
          _.extend(chip, model)
      else if 'splitter' of chip
        showDialog 'game/board/editBoardSplitter.tpl.html', 'EditBoardSplitterDialogCtrl', chip, (model) ->
          _.extend(chip, model)
      else if 'emitter' of chip
        showDialog 'game/board/editBoardEmitter.tpl.html', 'EditBoardEmitterDialogCtrl', chip, (model) ->
          _.extend(chip, model)

    $scope.$on 'editChipButtonClick', (event, chipPath) ->
      $scope.edit(chipPath)

    $scope.$on 'removeChipButtonClick', (event, chipPath) ->
      $scope.remove(chipPath)


.controller 'EditBoardEmitterDialogCtrl', ($scope, liaison, currentGame) ->
    $scope.DESTINATIONS = enumeratePinDestinations(currentGame.version)
    $scope.name = liaison.model.comment
    # Convert between 'pinDef form' used in game serialization and 'pin form' used in GUI
    $scope.pins = ({ input: input, output: output } for output, input of liaison.model.emitter)

    $scope.addPin = -> $scope.pins.push({ input: '', output: '' })
    $scope.removePin = (index) -> $scope.pins.splice(index, 1)

    # Reply with the new data
    $scope.done = -> liaison.done
      comment: $scope.name
      emitter: _.object(([output, input] for {input: input, output: output} in $scope.pins))
    $scope.cancel = -> liaison.cancel()


.controller 'EditBoardSplitterDialogCtrl', ($scope, liaison, currentGame) ->
    $scope.DESTINATIONS = enumeratePinDestinations(currentGame.version)
    $scope.name = liaison.model.comment
    $scope.from = liaison.model.splitter.from
    $scope.bindTo = liaison.model.splitter.bindTo
    $scope.index = liaison.model.splitter.index

    # Reply with the new data
    $scope.done = -> liaison.done
      comment: $scope.name
      splitter:
        from: $scope.from
        bindTo: $scope.bindTo
        index: $scope.index
    $scope.cancel = -> liaison.cancel()


.controller 'EditBoardProcessorDialogCtrl', ($scope, liaison, currentGame) ->
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
      for destination, expression in outValues
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
              pins.out[destination.drain] = destination.source
      return result

    $scope.LINKAGES = ['simple', 'custom']
    $scope.DESTINATIONS = enumeratePinDestinations(currentGame.version)
    $scope.name = liaison.model.comment

    # Depending on if this is an processor or a switch, get the right kind of data
    # TODO: move this to calling controller?
    typeDef = null
    if 'processor' of liaison.model
      $scope.kind = 'Processor'
      $scope.type = liaison.model.processor
      typeDef = currentGame.version.processors[$scope.type]
    else if 'switch' of liaison.model
      $scope.kind = 'Switch'
      $scope.type = liaison.model.switch
      typeDef = currentGame.version.switches[$scope.type]
    else
      throw new Error('Model is not a processor or switch')

    # TODO: refactor into function
    $scope.pins = []
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
      $scope.pins.push(pin)

    $scope.addCustomDestination = (pinName) ->
      pin = _.where($scope.pins, { name: pinName })[0]
      pin.customDestinations.out.push({ drain: '', source: '' })
    $scope.removeCustomDestination = (pinName, index) ->
      pin = _.where($scope.pins, { name: pinName })[0]
      pin.customDestinations.out.splice(index, 1)

    # Reply with the new data
    $scope.done = -> liaison.done
      comment: $scope.name
      pins: convertPinsToModel($scope.pins)
    $scope.cancel = -> liaison.cancel()
